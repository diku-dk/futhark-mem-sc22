-- LocVolCalib
-- ==
-- compiled input @ data/small.in
-- compiled input @ data/medium.in
-- compiled input @ data/large.in

def initGrid (s0: f32) (alpha: f32) (nu: f32) (t: f32) (numX: i64) (numY: i64) (numT: i64)
  : (i32, i32, [numX]f32, [numY]f32, [numT]f32) =
  let logAlpha = f32.log alpha
  let myTimeline = map (\i -> t * f32.i64 i / (f32.i64 numT - 1.0)) (iota numT)
  let (stdX, stdY) = (20.0 * alpha * s0 * f32.sqrt(t),
                      10.0 * nu         * f32.sqrt(t))
  let (dx, dy) = (stdX / f32.i64 numX, stdY / f32.i64 numY)
  let (myXindex, myYindex) = (i32.f32 (s0 / dx), i32.i64 numY / 2)
  let myX = tabulate numX (\i -> f32.i64 i * dx - f32.i32 myXindex * dx + s0)
  let myY = tabulate numY (\i -> f32.i64 i * dy - f32.i32 myYindex * dy + logAlpha)
  in (myXindex, myYindex, myX, myY, myTimeline)

-- make the innermost dimension of the result of size 4 instead of 3?
def initOperator [n] (x: [n]f32): ([n][3]f32,[n][3]f32) =
  let dxu     = x[1] - x[0]
  let dx_low  = [[0.0, -1.0 / dxu, 1.0 / dxu]]
  let dxx_low = [[0.0, 0.0, 0.0]]
  let dx_mids = map (\i ->
                       let dxl = x[i] - x[i-1]
                       let dxu = x[i+1] - x[i]
                       in ([ -dxu/dxl/(dxl+dxu), (dxu/dxl - dxl/dxu)/(dxl+dxu),      dxl/dxu/(dxl+dxu) ],
                           [  2.0/dxl/(dxl+dxu), -2.0*(1.0/dxl + 1.0/dxu)/(dxl+dxu), 2.0/dxu/(dxl+dxu) ]))
                    (1...n-2)
  let (dx_mid, dxx_mid) = unzip dx_mids
  let dxl      = x[n-1] - x[n-2]
  let dx_high  = [[-1.0 / dxl, 1.0 / dxl, 0.0 ]]
  let dxx_high = [[0.0, 0.0, 0.0 ]]
  let dx     = dx_low ++ dx_mid ++ dx_high :> [n][3]f32
  let dxx    = dxx_low ++ dxx_mid ++ dxx_high :> [n][3]f32
  in  (dx, dxx)

def setPayoff [numX][numY] (strike: f32, myX: [numX]f32, _myY: [numY]f32): *[numY][numX]f32 =
  replicate numY (map (\xi -> f32.max (xi-strike) 0.0) myX)

-- Returns new myMuX, myVarX, myMuY, myVarY.
def updateParams [numX][numY]
                (myX:  [numX]f32, myY: [numY]f32,
                 tnow: f32, _alpha: f32, beta: f32, nu: f32)
  : ([numY][numX]f32, [numY][numX]f32, [numX][numY]f32, [numX][numY]f32) =
  let myMuY  = replicate numX (replicate numY 0.0)
  let myVarY = replicate numX (replicate numY (nu*nu))
  let myMuX  = replicate numY (replicate numX 0.0)
  let myVarX = map (\yj ->
                      map (\xi -> f32.exp(2.0*(beta*f32.log(xi) + yj - 0.5*nu*nu*tnow)))
                          myX)
                   myY
  in  ( myMuX, myVarX, myMuY, myVarY )

let tridagSeq [n] (a:  [n]f32, b: *[n]f32, c: [n]f32, y: *[n]f32 ): *[n]f32 =
  #[unsafe]
  let (y,b) = loop (y, b) for i in 1..<n do
              let beta = a[i] / b[i-1]
              let b[i] = b[i] - beta*c[i-1]
              let y[i] = y[i] - beta*y[i-1]
              in  (y, b)
  let y[n-1] = y[n-1] / b[n-1]
  in loop y for i in n-2..n-3...0 do
     let y[i] = (y[i] - c[i] * y[i+1]) / b[i]
     in  y

def explicitMethod [m][n] (myD:    [m][3]f32,  myDD: [m][3]f32,
                           myMu:   [n][m]f32,  myVar: [n][m]f32,
                           result: [n][m]f32)
                  : *[n][m]f32 =
  map3 (\mu_row var_row result_row ->
          map5 (\dx dxx mu var j ->
                  let c1 = if 0 < j
                           then (mu*dx[0] + 0.5*var*dxx[0]) * #[unsafe] result_row[j-1]
                           else 0.0
                  let c3 = if j < (m-1)
                           then (mu*dx[2] + 0.5*var*dxx[2]) * #[unsafe] result_row[j+1]
                           else 0.0
                  let c2 =      (mu*dx[1] + 0.5*var*dxx[1]) * #[unsafe] result_row[j  ]
                  in  c1 + c2 + c3)
               myD myDD mu_row var_row (iota m))
       myMu myVar result

-- for implicitY: should be called with transpose(u) instead of u
def implicitMethod [n][m] (myD:  [m][3]f32,  myDD:  [m][3]f32,
                           myMu: [n][m]f32,  myVar: [n][m]f32,
                           u:   *[n][m]f32,  dtInv: f32)
                  : *[n][m]f32 =
  map3 (\mu_row var_row u_row  ->
          let (a,b,c) = unzip3 (map4 (\mu var d dd ->
                                        ( 0.0   - 0.5*(mu*d[0] + 0.5*var*dd[0])
                                        , dtInv - 0.5*(mu*d[1] + 0.5*var*dd[1])
                                        , 0.0   - 0.5*(mu*d[2] + 0.5*var*dd[2])))
                                     mu_row var_row myD myDD)
          in tridagSeq( a, copy b, c, copy u_row ))
       myMu myVar u

def rollback
  [numX][numY]
  (tnow: f32, tnext: f32, myResult: [numY][numX]f32,
   myMuX: [numY][numX]f32, myDx: [numX][3]f32, myDxx: [numX][3]f32, myVarX: [numY][numX]f32,
   myMuY: [numX][numY]f32, myDy: [numY][3]f32, myDyy: [numY][3]f32, myVarY: [numX][numY]f32)
  : [numY][numX]f32 =
  let dtInv = 1.0/(tnext-tnow)
  -- explicitX
  let u = explicitMethod(myDx, myDxx, myMuX, myVarX, myResult)
  let u = map2 (map2 (\u_el res_el  -> dtInv*res_el + 0.5*u_el)) u myResult
  -- explicitY
  let myResultTR = transpose(myResult)
  let v = explicitMethod(myDy, myDyy, myMuY, myVarY, myResultTR)
  let u = map2 (map2 (+)) u (transpose v)
  -- implicitX
  let u = implicitMethod(myDx, myDxx, myMuX, myVarX, u, dtInv)
  -- implicitY
  let y = map2 (map2 (\u_el v_el -> dtInv*u_el - 0.5*v_el))
               (transpose u) v
  let myResultTR = implicitMethod(myDy, myDyy, myMuY, myVarY, y, dtInv)
  in transpose myResultTR

def value(numX: i64, numY: i64, numT: i64, s0: f32, strike: f32, t: f32, alpha: f32, nu: f32, beta: f32): f32 =
  let (myXindex, myYindex, myX, myY, myTimeline) =
    initGrid s0 alpha nu t numX numY numT
  let (myDx, myDxx) = initOperator(myX)
  let (myDy, myDyy) = initOperator(myY)
  let myResult = setPayoff(strike, myX, myY)
  let numT' = numT - 1
  let myTimeline_neighbours = reverse (zip (init myTimeline :> [numT']f32)
                                           (tail myTimeline :> [numT']f32))
  let myResult = loop (myResult) for (tnow,tnext) in myTimeline_neighbours do
                 let (myMuX, myVarX, myMuY, myVarY) =
                   updateParams(myX, myY, tnow, alpha, beta, nu)
                 let myResult = rollback(tnow, tnext, myResult,
                                         myMuX, myDx, myDxx, myVarX,
                                         myMuY, myDy, myDyy, myVarY)

                 in myResult
  in myResult[myYindex,myXindex]

def main (outer_loop_count: i32) (numX: i32) (numY: i32) (numT: i32)
         (s0: f32) (t: f32) (alpha: f32) (nu: f32) (beta: f32): []f32 =
  let strikes = map (\i -> 0.001*f32.i64 i) (iota (i64.i32 outer_loop_count))
  let res =
    #[incremental_flattening(only_inner)]
    map (\x -> value(i64.i32 numX, i64.i32 numY, i64.i32 numT, s0, x, t, alpha, nu, beta))
    strikes
  in res
