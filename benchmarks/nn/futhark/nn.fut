-- Code and comments based on
-- https://github.com/kkushagra/rodinia/blob/master/openmp/nn
--
-- ==
--
-- random input { 100i64 30.0f32 90.0f32 [855280]f32 [855280]f32 }
-- random input { 100i64 30.0f32 90.0f32 [8552800]f32 [8552800]f32 }
-- random input { 100i64 30.0f32 90.0f32 [85528000]f32 [85528000]f32 }

def emptyRecord: (i32, f32) = (0, 0.0f32)

def main [numRecords]
         (resultsCount: i64)
         (lat: f32) (lng: f32)
         (locations_lat: [numRecords]f32)
         (locations_lng: [numRecords]f32)
        : ([resultsCount]i32, [resultsCount]f32) =
  let locations = zip locations_lat locations_lng
  let distance (lat_i: f32, lng_i: f32) =
    f32.sqrt((lat-lat_i)*(lat-lat_i) + (lng-lng_i)*(lng-lng_i) )
  let distances = map distance locations

  let results = replicate resultsCount emptyRecord
  let (results, _) =
    loop ((results, distances)) for i < resultsCount do
      let (minDist, minLoc) =
        reduce_comm (\(d1, i1) (d2,i2) ->
                         if      d1 < d2 then (d1, i1)
                         else if d2 < d1 then (d2, i2)
                         else if i1 < i2 then (d1, i1)
                         else                 (d2, i2)
                    ) (f32.inf, 0) (zip distances (map i32.i64 <| iota numRecords))

      let distances[minLoc] = f32.inf
      let results[i] = (minLoc, minDist)
      in (results, distances)
  in unzip results
