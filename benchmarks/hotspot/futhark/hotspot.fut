-- Code and comments based on
-- https://github.com/kkushagra/rodinia/blob/master/openmp/hotspot/hotspot_openmp.cpp
--
-- ==
-- random compiled input { 10i32 [8192][8192]f32 [8192][8192]f32 }
-- random compiled input { 10i32 [16384][16384]f32 [16384][16384]f32 }
-- random compiled input { 10i32 [32768][32768]f32 [32768][32768]f32 }

-- Maximum power density possible (say 300W for a 10mm x 10mm chip)
let max_pd: f32 = 3.0e6

-- Required precision in degrees
let precision: f32 = 0.001

let spec_heat_si: f32 = 1.75e6

let k_si: f32 = 100.0

-- Capacitance fitting factor
let factor_chip: f32 = 0.5

-- Chip parameters
let t_chip: f32 = 0.0005
let chip_height: f32 = 0.016
let chip_width: f32 = 0.016

-- Ambient temperature assuming no package at all
let amb_temp: f32 = 80.0

-- Transient solver driver routine: simply converts the heat transfer
-- differential equations to difference equations and solves the
-- difference equations by iterating.
--
-- Returns a new 'temp' array.
let compute_tran_temp [row][col]
                      (num_iterations: i32) (temp: [row][col]f32) (power: [row][col]f32): [row][col]f32 =
  #[unsafe]
  let grid_height = chip_height / f32.i64 row
  let grid_width = chip_width / f32.i64 col
  let cap = factor_chip * spec_heat_si * t_chip * grid_width * grid_height
  let rx = grid_width / (2 * k_si * t_chip * grid_height)
  let ry = grid_height / (2 * k_si * t_chip * grid_width)
  let rz = t_chip / (k_si * grid_height * grid_width)
  let max_slope = max_pd / (factor_chip * t_chip * spec_heat_si)
  let step = precision / max_slope
  let col_m_2 = col-2
  let row_m_2 = row-2
  in loop temp for _i < num_iterations do
     let helper r c t = temp[r,c] + step / cap * (power[r,c] + t + (amb_temp - temp[r,c]) / rz)
     let corners = tabulate_2d 2 2 (\r c ->
                                      let (r, down) = if r == 0 then (r, 1) else (row-1, row-2)
                                      let (c, right) = if c == 0 then (c, 1) else (col-1, col-2)
                                      in helper r c ((temp[r, right] - temp[r,c]) / rx + (temp[down, c] - temp[r,c]) / ry))
                               |> flatten
     let edge1 = map5 (\el right left above c ->
                         let c = c + 1
                         in helper 0 c ((right + left - 2 * el) / rx + (above - el) / ry))
                      (temp[0, 1:col-1] :> [col_m_2]f32)
                      (temp[0, 0:col-2] :> [col_m_2]f32)
                      (temp[0, 2:col-0] :> [col_m_2]f32)
                      (temp[1, 1:col-1] :> [col_m_2]f32)
                      (iota col_m_2)
     let edge2 = map5 (\el above below right r ->
                         let r = r + 1
                         in helper r (col-1) ((right - el) / rx + (above + below - 2 * el) / ry))
                      (temp[1:row-1, col-1] :> [row_m_2]f32)
                      (temp[0:row-2, col-1] :> [row_m_2]f32)
                      (temp[2:row-0, col-1] :> [row_m_2]f32)
                      (temp[1:row-1, col-2] :> [row_m_2]f32)
                      (iota row_m_2)
     let edge3 = map5 (\el right left above c ->
                         let c = c + 1
                         in helper (row-1) c ((right + left - 2 * el) / rx + (above - el) / ry))
                      (temp[row-1, 1:col-1] :> [col_m_2]f32)
                      (temp[row-1, 0:col-2] :> [col_m_2]f32)
                      (temp[row-1, 2:col-0] :> [col_m_2]f32)
                      (temp[row-2, 1:col-1] :> [col_m_2]f32)
                      (iota col_m_2)
     let edge4 = map5 (\el above below right r ->
                         let r = r + 1
                         in helper r 0 ((right - el) / rx + (above + below - 2 * el) / ry))
                      (temp[1:row-1, 0] :> [row_m_2]f32)
                      (temp[0:row-2, 0] :> [row_m_2]f32)
                      (temp[2:row-0, 0] :> [row_m_2]f32)
                      (temp[1:row-1, 1] :> [row_m_2]f32)
                      (iota row_m_2)
     let internal =
       tabulate_2d row_m_2 col_m_2
                   (\r c -> let r = r + 1
                            let c = c + 1
                            in helper r c
                                      ((temp[r, c+1] + temp[r, c-1] - 2 * temp[r, c]) / rx +
                                       (temp[r+1, c] + temp[r-1, c] - 2 * temp[r, c]) / ry))
     in concat_to row
                  [concat_to col corners[0:1] (concat edge1 corners[1:2])]
                  (concat (map3 (\e4 i e2 -> concat_to col [e4] (concat i [e2])) edge4 internal edge2)
                          [concat_to col corners[3:4] (concat edge3 corners[2:3])])
        -- |> map3 (map3 (\t pow el -> t + (step / cap) * (pow + (el + (amb_temp - t) / rz)))) temp power

let main [row][col] (num_iterations: i32) (temp: [row][col]f32) (power: [row][col]f32): [][]f32 =
  compute_tran_temp num_iterations temp power
