--VERSION: 5gather. Gathering rather than scattering.
--[f] refers to the flattened dimension, while [s] refers to the flattened dimension of spatial points only
--[n] refers to the number of possible directions plus a flag, which is 20 in total in this simulation

--Global variables:
let OMEGA = 1.95f32
let DFL1 = (1.0f32/ 3.0f32)
let DFL2 = (1.0f32/18.0f32)
let DFL3 = (1.0f32/36.0f32)

--Cell Entries
let C = 0i64
let S = 1i64
let N = 2i64
let W = 3i64
let E = 4i64
let B = 5i64
let T = 6i64
let SW = 7i64
let SE = 8i64
let NW = 9i64
let NE = 10i64
let SB = 11i64
let ST = 12i64
let NB = 13i64
let NT = 14i64
let WB = 15i64
let WT = 16i64
let EB = 17i64
let ET = 18i64
let FLAG = 19i64

let N_CELL_ENTRIES = 20i64

--FLAGS
let FLUID = 0.00f32
let OBSTACLE = 1.00f32
let ACCEL = 2.00f32

--SIZES
let SIZE = 120i64
let SIZE_X = SIZE
let SIZE_Y = SIZE
let SIZE_Z = 150i64

let PADDING_Z = 4i64

let PADDED_X = SIZE_X
let PADDED_Y = SIZE_Y
let PADDED_Z = SIZE_Z+PADDING_Z

let TOTAL_CELLS = SIZE_X*SIZE_Y*SIZE_Z
let TOTAL_PADDED_CELLS = PADDED_X*PADDED_Y*PADDED_Z

let REAL_SIZE = TOTAL_CELLS*N_CELL_ENTRIES

let MARGIN = (PADDING_Z/2)*PADDED_X*PADDED_Y

let ds: [FLAG][3]i64 =
[
 [0, 0, 0],
 [0, 1, 0],
 [0, -1, 0],
 [0, 0, 1],
 [0, 0, -1],
 [1, 0, 0],
 [-1, 0, 0],
 [0, 1, 1],
 [0, 1, -1],
 [0, -1, 1],
 [0, -1, -1],
 [1, 1, 0],
 [-1, 1, 0],
 [1, -1, 0],
 [-1, -1, 0],
 [1, 0, 1],
 [-1, 0, 1],
 [1, 0, -1],
 [-1, 0, -1]
] :> [FLAG][3]i64

let transvec: []i64 = [PADDED_X*PADDED_Y, PADDED_X, 1]

let dotprod (x: []i64) (y: []i64): i64 =
  reduce (+) 0 (map2 (*) x y)

let ind_offsets = map (\d -> dotprod d transvec) ds

let speeds [l] (rhos: [l]f32): (f32, f32, f32) =
 let ux = - rhos[W] + rhos[E] - rhos[SW] + rhos[SE] - rhos[NW] + rhos[NE] - rhos[WB] - rhos[WT] + rhos[EB] + rhos[ET]
 let uy = - rhos[S] + rhos[N] - rhos[SW] - rhos[SE] + rhos[NW] + rhos[NE] - rhos[SB] - rhos[ST] + rhos[NB] + rhos[NT]
 let uz = - rhos[B] + rhos[T] - rhos[SB] + rhos[ST] - rhos[NB] + rhos[NT] - rhos[WB] + rhos[WT] - rhos[EB] + rhos[ET]
 in (ux, uy, uz)

let perform_collision (rhos: []f32) (flag: f32): []f32 =
if flag == OBSTACLE then
  [
    rhos[C],  --C
    rhos[N],  --S
    rhos[S],  --N
    rhos[E],  --W
    rhos[W],  --E
    rhos[T],  --B
    rhos[B],  --T
    rhos[NE], --SW
    rhos[NW], --SE
    rhos[SE], --NW
    rhos[SW], --NE
    rhos[NT], --SB
    rhos[NB], --ST
    rhos[ST], --NB
    rhos[SB], --NT
    rhos[ET], --WB
    rhos[EB], --WT
    rhos[WT], --EB
    rhos[WB], --ET
    flag      --FLAG
  ]
else
  let rho = reduce (+) 0 rhos
  let (ux, uy, uz) =
    if flag == ACCEL
      then (0.005f32, 0.002f32, 0.000f32)
      else let (ux, uy, uz) = speeds(rhos)
           in (ux/rho, uy/rho, uz/rho)
  let u2 = 1.5f32*(ux*ux + uy*uy + uz*uz)
  let p0 = 1.0f32-OMEGA
  let p1 = DFL1*OMEGA*rho
  let p2 = DFL2*OMEGA*rho
  let p3 = DFL3*OMEGA*rho
  in [
       p0*rhos[C] + p1*(1.0f32 - u2),

       p0*rhos[S]  + p2*(1.0f32 + uy*(4.5f32*uy - 3.0f32) - u2),
       p0*rhos[N]  + p2*(1.0f32 + uy*(4.5f32*uy + 3.0f32) - u2),
       p0*rhos[W]  + p2*(1.0f32 + ux*(4.5f32*ux - 3.0f32) - u2),
       p0*rhos[E]  + p2*(1.0f32 + ux*(4.5f32*ux + 3.0f32) - u2),
       p0*rhos[B]  + p2*(1.0f32 + uz*(4.5f32*uz - 3.0f32) - u2),
       p0*rhos[T]  + p2*(1.0f32 + uz*(4.5f32*uz + 3.0f32) - u2),

       p0*rhos[SW] + p3*(1.0f32 + (-ux-uy)*(4.5f32*(-ux-uy) + 3.0f32) - u2),
       p0*rhos[SE] + p3*(1.0f32 + ( ux-uy)*(4.5f32*( ux-uy) + 3.0f32) - u2),
       p0*rhos[NW] + p3*(1.0f32 + (-ux+uy)*(4.5f32*(-ux+uy) + 3.0f32) - u2),
       p0*rhos[NE] + p3*(1.0f32 + ( ux+uy)*(4.5f32*( ux+uy) + 3.0f32) - u2),
       p0*rhos[SB] + p3*(1.0f32 + (-uy-uz)*(4.5f32*(-uy-uz) + 3.0f32) - u2),
       p0*rhos[ST] + p3*(1.0f32 + (-uy+uz)*(4.5f32*(-uy+uz) + 3.0f32) - u2),
       p0*rhos[NB] + p3*(1.0f32 + ( uy-uz)*(4.5f32*( uy-uz) + 3.0f32) - u2),
       p0*rhos[NT] + p3*(1.0f32 + ( uy+uz)*(4.5f32*( uy+uz) + 3.0f32) - u2),
       p0*rhos[WB] + p3*(1.0f32 + (-ux-uz)*(4.5f32*(-ux-uz) + 3.0f32) - u2),
       p0*rhos[WT] + p3*(1.0f32 + (-ux+uz)*(4.5f32*(-ux+uz) + 3.0f32) - u2),
       p0*rhos[EB] + p3*(1.0f32 + ( ux-uz)*(4.5f32*( ux-uz) + 3.0f32) - u2),
       p0*rhos[ET] + p3*(1.0f32 + ( ux+uz)*(4.5f32*( ux+uz) + 3.0f32) - u2),
       flag
     ]

--Performs the first collision step at the very beginning of the simulation.
--This saves one gather.

let collide [n][s] (grid_2d: *[n][s]f32): *[n][s]f32  =
let collided =
map (\i : [n]f32 ->
 if (i < MARGIN || i > (TOTAL_PADDED_CELLS - MARGIN))
    then grid_2d[:, i]
 else
   let rhos = grid_2d[0:FLAG:1, i] in
   (perform_collision rhos grid_2d[FLAG, i]) :> [n]f32
  )
(iota s) in
transpose collided

let gather_collide [n][s] (grid_2d: *[n][s]f32): *[n][s]f32  =
  let collided =
  map (\i : [n]f32 ->
   if (i < MARGIN || i > (TOTAL_PADDED_CELLS - MARGIN))
      then grid_2d[:, i]
   else
     let inds = map (\ind_offset -> i + ind_offset) ind_offsets
     let rhos = map2 (\j ind-> grid_2d[j, ind]) (iota (FLAG)) inds
     in
     (perform_collision rhos grid_2d[FLAG, i]) :> [n]f32
    )
(iota s) in
transpose collided

--performs the final gather such that an integer number of cycles of collide-gather
--are performed doing the simulation.

let gather [n][s] (grid_2d: *[n][s]f32): *[n][s]f32  =
  let gathered =
  map (\i : [n]f32 ->
    if (i < MARGIN || i > (TOTAL_PADDED_CELLS - MARGIN))
      then grid_2d[:, i]
    else
      let inds = map (\ind_offset -> i + ind_offset) ind_offsets
      in
      [
        grid_2d[C, inds[C]],
        grid_2d[S, inds[S]],
        grid_2d[N, inds[N]],
        grid_2d[W, inds[W]],
        grid_2d[E, inds[E]],
        grid_2d[B, inds[B]],
        grid_2d[T, inds[T]],
        grid_2d[SW, inds[SW]],
        grid_2d[SE, inds[SE]],
        grid_2d[NW, inds[NW]],
        grid_2d[NE, inds[NE]],
        grid_2d[SB, inds[SB]],
        grid_2d[ST, inds[ST]],
        grid_2d[NB, inds[NB]],
        grid_2d[NT, inds[NT]],
        grid_2d[WB, inds[WB]],
        grid_2d[WT, inds[WT]],
        grid_2d[EB, inds[EB]],
        grid_2d[ET, inds[ET]],
        grid_2d[FLAG, i]
      ] :> [n]f32)
  (iota s) in
  transpose gathered


let main [f] (steps: i64) (grid_init: *[f]f32): *[f]f32 =
  #[unsafe]
   let grid_2d = unflatten N_CELL_ENTRIES TOTAL_PADDED_CELLS grid_init
   let first_collide = collide grid_2d
   let looped =
   loop g = first_collide for _i < (steps-1) do
   gather_collide g
   in flatten_to f (gather looped)


--Benchmark
-- ==
-- compiled input @ data/short.data.gz
-- compiled input @ data/long.data.gz
