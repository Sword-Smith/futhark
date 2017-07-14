-- Test that a stream reduction with an array is kernel-extracted
-- properly: this involves interchanging the reduction (twice) so that
-- is becomes a map-with-reduce (actually a segmented reduction).
--
-- This test is inspired by kmeans.
--
-- ==
-- tags { no_python }
-- input { 3 100 5 }
-- output { [[0.8051474f32, -7.109213e-2f32, -2.8099937f32],
--          [2.1506262f32, 2.51387f32, -1.8687513f32],
--          [1.5188317f32, -0.13410425f32, 4.0366645f32],
--          [-0.5093703f32, -0.5954051f32, -4.6837516f32],
--          [-2.0692608f32, 0.18270588f32, 7.2218027f32]]
-- }
-- compiled input { 30 100000 5 }
-- output {
--   [[-0.006780f32, 0.000599f32, 0.023664f32, -0.002089f32, 0.002644f32,
--   -0.003372f32, -0.009227f32, 0.011768f32, 0.012901f32, 0.016603f32,
--   -0.005197f32, -0.002152f32, 0.003090f32, -0.009622f32, 0.000831f32,
--   -0.000224f32, 0.014589f32, 0.005129f32, -0.024606f32, 0.004497f32,
--   -0.000645f32, 0.004965f32, 0.015765f32, -0.005824f32, -0.016589f32,
--   -0.015354f32, 0.013409f32, 0.008050f32, 0.002794f32, 0.013659f32],
--   [0.000442f32, 0.000516f32, -0.019338f32, 0.011012f32, 0.005266f32,
--   0.008358f32, 0.013427f32, -0.015314f32, 0.000351f32, 0.023183f32,
--   -0.002456f32, -0.001275f32, 0.005614f32, -0.028932f32, 0.006416f32,
--   0.010362f32, 0.003526f32, 0.003003f32, 0.025215f32, -0.007248f32,
--   -0.000452f32, -0.002234f32, -0.013284f32, 0.015155f32, 0.001544f32,
--   -0.018070f32, 0.007009f32, 0.004596f32, -0.001740f32, 0.028762f32],
--   [0.007258f32, -0.000641f32, 0.019290f32, -0.001703f32, 0.004249f32,
--   0.015409f32, -0.018770f32, -0.009157f32, 0.000407f32, -0.042462f32,
--   0.010037f32, 0.005357f32, -0.011571f32, 0.051894f32, 0.003190f32,
--   0.006424f32, -0.007196f32, 0.001678f32, -0.014979f32, 0.007989f32,
--   0.001380f32, -0.007693f32, 0.021237f32, 0.007103f32, 0.010479f32,
--   0.045474f32, -0.010942f32, -0.003838f32, 0.011732f32, -0.045759f32],
--   [0.007401f32, 0.008651f32, -0.011974f32, 0.001613f32, 0.000434f32,
--   -0.006294f32, 0.011299f32, 0.004170f32, -0.020269f32, 0.043208f32,
--   0.008622f32, 0.002530f32, 0.020483f32, -0.058146f32, -0.000917f32,
--   0.002877f32, -0.006786f32, -0.005740f32, 0.018384f32, 0.002303f32,
--   0.003693f32, 0.008936f32, -0.008334f32, 0.000654f32, 0.027996f32,
--   -0.033219f32, -0.008201f32, -0.000513f32, -0.016410f32, 0.056011f32],
--   [0.000740f32, -0.000065f32, -0.002582f32, 0.000228f32, -0.003533f32,
--   -0.005041f32, 0.012332f32, 0.017592f32, 0.015671f32, -0.031472f32,
--   -0.001946f32, 0.004600f32, -0.008555f32, 0.053867f32, -0.000460f32,
--   -0.010379f32, 0.004927f32, 0.004990f32, 0.005046f32, 0.001519f32,
--   0.005085f32, 0.005086f32, -0.006324f32, -0.008027f32, -0.014370f32,
--   0.030229f32, 0.007785f32, 0.000765f32, 0.012684f32, -0.043612f32]]
-- }
-- compiled input { 30 1000000 10 }
-- output { [[0.000166f32, 0.000160f32, -0.000578f32, -0.000557f32,
-- -0.000190f32, -0.000183f32, 0.000662f32, 0.000638f32, 0.000600f32,
-- -0.000729f32, -0.000008f32, 0.000185f32, -0.000686f32, 0.000834f32,
-- 0.000009f32, -0.000212f32, -0.000082f32, -0.000198f32, 0.000701f32,
-- 0.000632f32, 0.000221f32, 0.000152f32, -0.000558f32, -0.000560f32,
-- -0.000464f32, 0.000802f32, 0.000089f32, -0.000223f32, 0.000714f32,
-- -0.000746f32], [0.000160f32, 0.000166f32, -0.000557f32,
-- -0.000578f32, -0.000183f32, -0.000190f32, 0.000638f32, 0.000662f32,
-- -0.000729f32, 0.000600f32, 0.000185f32, -0.000008f32, 0.000834f32,
-- -0.000686f32, -0.000212f32, 0.000009f32, -0.000198f32,
-- -0.000082f32, 0.000632f32, 0.000701f32, 0.000152f32, 0.000221f32,
-- -0.000560f32, -0.000558f32, 0.000802f32, -0.000464f32,
-- -0.000223f32, 0.000089f32, -0.000746f32, 0.000714f32],
-- [0.000007f32, -0.000152f32, 0.000018f32, -0.000405f32, 0.000303f32,
-- 0.000275f32, -0.000223f32, 0.000144f32, -0.000803f32, -0.000988f32,
-- 0.000128f32, -0.000066f32, 0.000952f32, 0.001417f32, 0.000130f32,
-- 0.000088f32, 0.000013f32, 0.000175f32, 0.000112f32, 0.000468f32,
-- -0.000142f32, -0.000204f32, 0.000190f32, -0.000238f32, 0.000888f32,
-- 0.000851f32, -0.000101f32, 0.000119f32, -0.000836f32,
-- -0.001278f32], [-0.000152f32, 0.000007f32, -0.000405f32,
-- 0.000018f32, 0.000275f32, 0.000303f32, 0.000144f32, -0.000223f32,
-- -0.000988f32, -0.000803f32, -0.000066f32, 0.000128f32, 0.001417f32,
-- 0.000952f32, 0.000088f32, 0.000130f32, 0.000175f32, 0.000013f32,
-- 0.000468f32, 0.000112f32, -0.000204f32, -0.000142f32, -0.000238f32,
-- 0.000190f32, 0.000851f32, 0.000888f32, 0.000119f32, -0.000101f32,
-- -0.001278f32, -0.000836f32], [-0.000171f32, -0.000033f32,
-- 0.000598f32, 0.000115f32, 0.000028f32, 0.000005f32, -0.000097f32,
-- -0.000019f32, -0.000806f32, -0.000155f32, 0.000035f32, 0.000007f32,
-- 0.001510f32, 0.000291f32, -0.000209f32, -0.000040f32, 0.000325f32,
-- 0.000062f32, -0.000638f32, -0.000123f32, -0.000019f32,
-- -0.000004f32, 0.000321f32, 0.000062f32, 0.000664f32, 0.000128f32,
-- 0.000133f32, 0.000026f32, -0.001241f32, -0.000239f32],
-- [-0.000033f32, -0.000171f32, 0.000115f32, 0.000598f32, 0.000005f32,
-- 0.000028f32, -0.000019f32, -0.000097f32, -0.000155f32,
-- -0.000806f32, 0.000007f32, 0.000035f32, 0.000291f32, 0.001510f32,
-- -0.000040f32, -0.000209f32, 0.000062f32, 0.000325f32, -0.000123f32,
-- -0.000638f32, -0.000004f32, -0.000019f32, 0.000062f32, 0.000321f32,
-- 0.000128f32, 0.000664f32, 0.000026f32, 0.000133f32, -0.000239f32,
-- -0.001241f32], [0.000136f32, 0.000180f32, 0.000361f32, 0.000478f32,
-- 0.000121f32, -0.000194f32, -0.000379f32, -0.000260f32,
-- -0.000104f32, 0.000813f32, 0.000204f32, 0.000130f32, -0.000083f32,
-- -0.001250f32, 0.000077f32, -0.000048f32, -0.000132f32,
-- -0.000198f32, -0.000263f32, -0.000497f32, 0.000006f32, 0.000178f32,
-- 0.000421f32, 0.000356f32, 0.000318f32, -0.000619f32, -0.000217f32,
-- -0.000180f32, 0.000102f32, 0.001137f32], [0.000180f32, 0.000136f32,
-- 0.000478f32, 0.000361f32, -0.000194f32, 0.000121f32, -0.000260f32,
-- -0.000379f32, 0.000813f32, -0.000104f32, 0.000130f32, 0.000204f32,
-- -0.001250f32, -0.000083f32, -0.000048f32, 0.000077f32,
-- -0.000198f32, -0.000132f32, -0.000497f32, -0.000263f32,
-- 0.000178f32, 0.000006f32, 0.000356f32, 0.000421f32, -0.000619f32,
-- 0.000318f32, -0.000180f32, -0.000217f32, 0.001137f32, 0.000102f32],
-- [0.000058f32, -0.000117f32, -0.000204f32, 0.000407f32,
-- -0.000067f32, 0.000133f32, 0.000233f32, -0.000465f32, 0.001308f32,
-- 0.001096f32, -0.000164f32, -0.000218f32, -0.001497f32,
-- -0.001254f32, 0.000188f32, 0.000249f32, 0.000071f32, 0.000196f32,
-- 0.000283f32, -0.000443f32, 0.000129f32, -0.000084f32, -0.000178f32,
-- 0.000419f32, -0.001211f32, -0.001124f32, 0.000291f32, 0.000297f32,
-- 0.001455f32, 0.001163f32], [-0.000117f32, 0.000058f32, 0.000407f32,
-- -0.000204f32, 0.000133f32, -0.000067f32, -0.000465f32, 0.000233f32,
-- 0.001096f32, 0.001308f32, -0.000218f32, -0.000164f32, -0.001254f32,
-- -0.001497f32, 0.000249f32, 0.000188f32, 0.000196f32, 0.000071f32,
-- -0.000443f32, 0.000283f32, -0.000084f32, 0.000129f32, 0.000419f32,
-- -0.000178f32, -0.001124f32, -0.001211f32, 0.000297f32, 0.000291f32,
-- 0.001163f32, 0.001455f32]]}
-- structure distributed { Kernel 6 }

import "/futlib/math"

let main(nfeatures: i32, npoints: i32, nclusters: i32): [nclusters][nfeatures]f32 =
  let membership = map (%nclusters) (iota(npoints))
  let features_in_cluster = replicate nclusters (npoints / nclusters)
  -- Just generate some random-seeming points.
  let points = map (\(i: i32): [nfeatures]f32  ->
                     map (*100f32) (map f32.sin (map f32 (map (^i) (iota(nfeatures)))))
                  ) (iota(npoints)) in
  stream_red_per (\(acc: *[#nclusters][#nfeatures]f32)
                  (elem: *[#nclusters][#nfeatures]f32): *[nclusters][nfeatures]f32  ->
                 map (\(x: []f32) (y: []f32): [nfeatures]f32  ->
                           map (+) x y) acc elem) (
                 \(inp: [#chunk]([#nfeatures]f32,i32)): *[nclusters][nfeatures]f32  ->
                   loop acc = replicate nclusters (replicate nfeatures 0.0f32) for i < chunk do
                     let (point, c) = inp[i] in
                     unsafe let acc[c] = map (+) (acc[c]) (map (/f32(features_in_cluster[c])) point) in
                     acc) (zip points membership)
