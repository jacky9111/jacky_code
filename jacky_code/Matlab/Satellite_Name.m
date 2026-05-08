function [] = Satellite_Name()

global OneWeb_leo OneWeb_geo  OneWeb_OMNet_leo OneWeb_OMNet_geo beam_config geoLongitudes OneWeb_OMNet_leo_part OneWeb_OMNet_geo_part;

% Auto-generated from OneWeb TLE file by helper script.
% Plane grouping is inferred by binning RAAN (rounded to nearest degree).
% Iridium holds the exact TLE object names; Iridium_OMNet assigns ow{plane}_{index} IDs.

Plane = [
    "Plane_1"
    "Plane_2"
    "Plane_3"
    "Plane_4"
    "Plane_5"
    "Plane_6"
    "Plane_7"
    "Plane_8"
    "Plane_9"
    "Plane_10"
    "Plane_11"
    "Plane_12"
    "Plane_13"
    "Plane_14"
    "Plane_15"
    "Plane_16"
    "Plane_17"
    "Plane_18"
    "Plane_19"
];

OneWeb_OMNet_leo = [
    "ow1_1" % 0 ONEWEB 0160  % plane 1 idx 1
    "ow1_2" % 0 ONEWEB 0170  % plane 1 idx 2
    "ow1_3" % 0 ONEWEB 0158  % plane 1 idx 3
    "ow1_4" % 0 ONEWEB 0322  % plane 1 idx 4
    "ow1_5" % 0 ONEWEB 0175  % plane 1 idx 5
    "ow1_6" % 0 ONEWEB 0152  % plane 1 idx 6
    "ow1_7" % 0 ONEWEB 0116  % plane 1 idx 7
    "ow1_8" % 0 ONEWEB 0352  % plane 1 idx 8
    "ow1_9" % 0 ONEWEB 0113  % plane 1 idx 9
    "ow1_10" % 0 ONEWEB 0333  % plane 1 idx 10
    "ow1_11" % 0 ONEWEB 0164  % plane 1 idx 11
    "ow1_12" % 0 ONEWEB 0569  % plane 1 idx 12
    "ow1_13" % 0 ONEWEB 0115  % plane 1 idx 13
    "ow1_14" % 0 ONEWEB 0154  % plane 1 idx 14
    "ow1_15" % 0 ONEWEB 0108  % plane 1 idx 15
    "ow1_16" % 0 ONEWEB 0171  % plane 1 idx 16
    "ow1_17" % 0 ONEWEB 0169  % plane 1 idx 17
    "ow1_18" % 0 ONEWEB 0151  % plane 1 idx 18
    "ow1_19" % 0 ONEWEB 0307  % plane 1 idx 19
    "ow1_20" % 0 ONEWEB 0155  % plane 1 idx 20
    "ow1_21" % 0 ONEWEB 0339  % plane 1 idx 21
    "ow1_22" % 0 ONEWEB 0101  % plane 1 idx 22
    "ow1_23" % 0 ONEWEB 0172  % plane 1 idx 23
    "ow1_24" % 0 ONEWEB 0178  % plane 1 idx 24
    "ow1_25" % 0 ONEWEB 0167  % plane 1 idx 25
    "ow1_26" % 0 ONEWEB 0153  % plane 1 idx 26
    "ow1_27" % 0 ONEWEB 0112  % plane 1 idx 27
    "ow1_28" % 0 ONEWEB 0292  % plane 1 idx 28
    "ow1_29" % 0 ONEWEB 0335  % plane 1 idx 29
    "ow1_30" % 0 ONEWEB 0355  % plane 1 idx 30
    "ow1_31" % 0 ONEWEB 0162  % plane 1 idx 31
    "ow1_32" % 0 ONEWEB 0156  % plane 1 idx 32
    "ow1_33" % 0 ONEWEB 0150  % plane 1 idx 33
    "ow1_34" % 0 ONEWEB 0328  % plane 1 idx 34
    "ow1_35" % 0 ONEWEB 0149  % plane 1 idx 35
    "ow1_36" % 0 ONEWEB 0161  % plane 1 idx 36
    "ow1_37" % 0 ONEWEB 0177  % plane 1 idx 37
    "ow1_38" % 0 ONEWEB 0174  % plane 1 idx 38
    "ow1_39" % 0 ONEWEB 0168  % plane 1 idx 39
    "ow1_40" % 0 ONEWEB 0166  % plane 1 idx 40
    "ow1_41" % 0 ONEWEB 0163  % plane 1 idx 41
    "ow1_42" % 0 ONEWEB 0337  % plane 1 idx 42
    "ow1_43" % 0 ONEWEB 0173  % plane 1 idx 43
    "ow1_44" % 0 ONEWEB 0107  % plane 1 idx 44
    "ow1_45" % 0 ONEWEB 0159  % plane 1 idx 45
    "ow1_46" % 0 ONEWEB 0350  % plane 1 idx 46
    "ow1_47" % 0 ONEWEB 0345  % plane 1 idx 47
    "ow1_48" % 0 ONEWEB 0157  % plane 1 idx 48
    "ow1_49" % 0 ONEWEB 0336  % plane 1 idx 49
    "ow1_50" % 0 ONEWEB 0344  % plane 1 idx 50
    "ow1_51" % 0 ONEWEB 0148  % plane 1 idx 51
    "ow2_1" % 0 ONEWEB 0402  % plane 2 idx 1
    "ow2_2" % 0 ONEWEB 0440  % plane 2 idx 2
    "ow2_3" % 0 ONEWEB 0412  % plane 2 idx 3
    "ow2_4" % 0 ONEWEB 0405  % plane 2 idx 4
    "ow2_5" % 0 ONEWEB 0421  % plane 2 idx 5
    "ow2_6" % 0 ONEWEB 0420  % plane 2 idx 6
    "ow2_7" % 0 ONEWEB 0401  % plane 2 idx 7
    "ow2_8" % 0 ONEWEB 0414  % plane 2 idx 8
    "ow2_9" % 0 ONEWEB 0426  % plane 2 idx 9
    "ow2_10" % 0 ONEWEB 0327  % plane 2 idx 10
    "ow2_11" % 0 ONEWEB 0397  % plane 2 idx 11
    "ow2_12" % 0 ONEWEB 0450  % plane 2 idx 12
    "ow2_13" % 0 ONEWEB 0560  % plane 2 idx 13
    "ow2_14" % 0 ONEWEB 0429  % plane 2 idx 14
    "ow2_15" % 0 ONEWEB 0306  % plane 2 idx 15
    "ow2_16" % 0 ONEWEB 0325  % plane 2 idx 16
    "ow2_17" % 0 ONEWEB 0396  % plane 2 idx 17
    "ow2_18" % 0 ONEWEB 0394  % plane 2 idx 18
    "ow2_19" % 0 ONEWEB 0326  % plane 2 idx 19
    "ow2_20" % 0 ONEWEB 0340  % plane 2 idx 20
    "ow2_21" % 0 ONEWEB 0318  % plane 2 idx 21
    "ow2_22" % 0 ONEWEB 0303  % plane 2 idx 22
    "ow2_23" % 0 ONEWEB 0400  % plane 2 idx 23
    "ow2_24" % 0 ONEWEB 0419  % plane 2 idx 24
    "ow2_25" % 0 ONEWEB 0346  % plane 2 idx 25
    "ow2_26" % 0 ONEWEB 0320  % plane 2 idx 26
    "ow2_27" % 0 ONEWEB 0324  % plane 2 idx 27
    "ow2_28" % 0 ONEWEB 0343  % plane 2 idx 28
    "ow2_29" % 0 ONEWEB 0427  % plane 2 idx 29
    "ow2_30" % 0 ONEWEB 0417  % plane 2 idx 30
    "ow2_31" % 0 ONEWEB 0331  % plane 2 idx 31
    "ow2_32" % 0 ONEWEB 0424  % plane 2 idx 32
    "ow2_33" % 0 ONEWEB 0631  % plane 2 idx 33
    "ow2_34" % 0 ONEWEB 0418  % plane 2 idx 34
    "ow2_35" % 0 ONEWEB 0406  % plane 2 idx 35
    "ow2_36" % 0 ONEWEB 0432  % plane 2 idx 36
    "ow3_1" % 0 ONEWEB 0413  % plane 3 idx 1
    "ow3_2" % 0 ONEWEB 0543  % plane 3 idx 2
    "ow3_3" % 0 ONEWEB 0407  % plane 3 idx 3
    "ow3_4" % 0 ONEWEB 0544  % plane 3 idx 4
    "ow3_5" % 0 ONEWEB 0316  % plane 3 idx 5
    "ow3_6" % 0 ONEWEB 0430  % plane 3 idx 6
    "ow3_7" % 0 ONEWEB 0403  % plane 3 idx 7
    "ow3_8" % 0 ONEWEB 0341  % plane 3 idx 8
    "ow3_9" % 0 ONEWEB 0567  % plane 3 idx 9
    "ow3_10" % 0 ONEWEB 0565  % plane 3 idx 10
    "ow3_11" % 0 ONEWEB 0571  % plane 3 idx 11
    "ow3_12" % 0 ONEWEB 0588  % plane 3 idx 12
    "ow3_13" % 0 ONEWEB 0570  % plane 3 idx 13
    "ow3_14" % 0 ONEWEB 0573  % plane 3 idx 14
    "ow4_1" % 0 ONEWEB 0301  % plane 4 idx 1
    "ow4_2" % 0 ONEWEB 0146  % plane 4 idx 2
    "ow4_3" % 0 ONEWEB 0300  % plane 4 idx 3
    "ow4_4" % 0 ONEWEB 0110  % plane 4 idx 4
    "ow4_5" % 0 ONEWEB 0135  % plane 4 idx 5
    "ow4_6" % 0 ONEWEB 0124  % plane 4 idx 6
    "ow4_7" % 0 ONEWEB 0121  % plane 4 idx 7
    "ow4_8" % 0 ONEWEB 0533  % plane 4 idx 8
    "ow4_9" % 0 ONEWEB 0133  % plane 4 idx 9
    "ow4_10" % 0 ONEWEB 0128  % plane 4 idx 10
    "ow4_11" % 0 ONEWEB 0147  % plane 4 idx 11
    "ow4_12" % 0 ONEWEB 0131  % plane 4 idx 12
    "ow4_13" % 0 ONEWEB 0117  % plane 4 idx 13
    "ow4_14" % 0 ONEWEB 0130  % plane 4 idx 14
    "ow4_15" % 0 ONEWEB 0138  % plane 4 idx 15
    "ow4_16" % 0 ONEWEB 0308  % plane 4 idx 16
    "ow4_17" % 0 ONEWEB 0122  % plane 4 idx 17
    "ow4_18" % 0 ONEWEB 0140  % plane 4 idx 18
    "ow4_19" % 0 ONEWEB 0317  % plane 4 idx 19
    "ow4_20" % 0 ONEWEB 0119  % plane 4 idx 20
    "ow4_21" % 0 ONEWEB 0132  % plane 4 idx 21
    "ow4_22" % 0 ONEWEB 0143  % plane 4 idx 22
    "ow4_23" % 0 ONEWEB 0136  % plane 4 idx 23
    "ow4_24" % 0 ONEWEB 0139  % plane 4 idx 24
    "ow4_25" % 0 ONEWEB 0285  % plane 4 idx 25
    "ow4_26" % 0 ONEWEB 0111  % plane 4 idx 26
    "ow4_27" % 0 ONEWEB 0123  % plane 4 idx 27
    "ow4_28" % 0 ONEWEB 0134  % plane 4 idx 28
    "ow4_29" % 0 ONEWEB 0145  % plane 4 idx 29
    "ow4_30" % 0 ONEWEB 0125  % plane 4 idx 30
    "ow4_31" % 0 ONEWEB 0109  % plane 4 idx 31
    "ow4_32" % 0 ONEWEB 0127  % plane 4 idx 32
    "ow4_33" % 0 ONEWEB 0297  % plane 4 idx 33
    "ow4_34" % 0 ONEWEB 0126  % plane 4 idx 34
    "ow4_35" % 0 ONEWEB 0310  % plane 4 idx 35
    "ow4_36" % 0 ONEWEB 0286  % plane 4 idx 36
    "ow4_37" % 0 ONEWEB 0102  % plane 4 idx 37
    "ow4_38" % 0 ONEWEB 0120  % plane 4 idx 38
    "ow4_39" % 0 ONEWEB 0315  % plane 4 idx 39
    "ow4_40" % 0 ONEWEB 0144  % plane 4 idx 40
    "ow4_41" % 0 ONEWEB 0288  % plane 4 idx 41
    "ow4_42" % 0 ONEWEB 0137  % plane 4 idx 42
    "ow4_43" % 0 ONEWEB 0628  % plane 4 idx 43
    "ow4_44" % 0 ONEWEB 0294  % plane 4 idx 44
    "ow4_45" % 0 ONEWEB 0302  % plane 4 idx 45
    "ow4_46" % 0 ONEWEB 0114  % plane 4 idx 46
    "ow4_47" % 0 ONEWEB 0624  % plane 4 idx 47
    "ow4_48" % 0 ONEWEB 0141  % plane 4 idx 48
    "ow4_49" % 0 ONEWEB 0118  % plane 4 idx 49
    "ow4_50" % 0 ONEWEB 0142  % plane 4 idx 50
    "ow4_51" % 0 ONEWEB 0296  % plane 4 idx 51
    "ow4_52" % 0 ONEWEB 0323  % plane 4 idx 52
    "ow4_53" % 0 ONEWEB 0129  % plane 4 idx 53
    "ow5_1" % 0 ONEWEB 0693  % plane 5 idx 1
    "ow5_2" % 0 ONEWEB 0475  % plane 5 idx 2
    "ow5_3" % 0 ONEWEB 0616  % plane 5 idx 3
    "ow5_4" % 0 ONEWEB 0422  % plane 5 idx 4
    "ow5_5" % 0 ONEWEB 0629  % plane 5 idx 5
    "ow5_6" % 0 ONEWEB 0619  % plane 5 idx 6
    "ow5_7" % 0 ONEWEB 0719  % plane 5 idx 7
    "ow5_8" % 0 ONEWEB 0716  % plane 5 idx 8
    "ow5_9" % 0 ONEWEB 0452  % plane 5 idx 9
    "ow5_10" % 0 ONEWEB 0625  % plane 5 idx 10
    "ow5_11" % 0 ONEWEB 0443  % plane 5 idx 11
    "ow5_12" % 0 ONEWEB 0436  % plane 5 idx 12
    "ow5_13" % 0 ONEWEB 0423  % plane 5 idx 13
    "ow5_14" % 0 ONEWEB 0298  % plane 5 idx 14
    "ow5_15" % 0 ONEWEB 0094  % plane 5 idx 15
    "ow5_16" % 0 ONEWEB 0463  % plane 5 idx 16
    "ow5_17" % 0 ONEWEB 0599  % plane 5 idx 17
    "ow5_18" % 0 ONEWEB 0451  % plane 5 idx 18
    "ow5_19" % 0 ONEWEB 0290  % plane 5 idx 19
    "ow5_20" % 0 ONEWEB 0389  % plane 5 idx 20
    "ow5_21" % 0 ONEWEB 0293  % plane 5 idx 21
    "ow5_22" % 0 ONEWEB 0299  % plane 5 idx 22
    "ow5_23" % 0 ONEWEB 0393  % plane 5 idx 23
    "ow5_24" % 0 ONEWEB 0313  % plane 5 idx 24
    "ow5_25" % 0 ONEWEB 0295  % plane 5 idx 25
    "ow5_26" % 0 ONEWEB 0304  % plane 5 idx 26
    "ow5_27" % 0 ONEWEB 0329  % plane 5 idx 27
    "ow5_28" % 0 ONEWEB 0461  % plane 5 idx 28
    "ow5_29" % 0 ONEWEB 0710  % plane 5 idx 29
    "ow5_30" % 0 ONEWEB 0626  % plane 5 idx 30
    "ow5_31" % 0 ONEWEB 0572  % plane 5 idx 31
    "ow5_32" % 0 ONEWEB 0289  % plane 5 idx 32
    "ow5_33" % 0 ONEWEB 0311  % plane 5 idx 33
    "ow5_34" % 0 ONEWEB 0390  % plane 5 idx 34
    "ow5_35" % 0 ONEWEB 0330  % plane 5 idx 35
    "ow5_36" % 0 ONEWEB 0392  % plane 5 idx 36
    "ow5_37" % 0 ONEWEB 0309  % plane 5 idx 37
    "ow5_38" % 0 ONEWEB 0319  % plane 5 idx 38
    "ow5_39" % 0 ONEWEB 0027  % plane 5 idx 39
    "ow5_40" % 0 ONEWEB 0717  % plane 5 idx 40
    "ow5_41" % 0 ONEWEB 0312  % plane 5 idx 41
    "ow5_42" % 0 ONEWEB 0291  % plane 5 idx 42
    "ow5_43" % 0 ONEWEB 0305  % plane 5 idx 43
    "ow5_44" % 0 ONEWEB 0532  % plane 5 idx 44
    "ow5_45" % 0 ONEWEB 0688  % plane 5 idx 45
    "ow5_46" % 0 ONEWEB 0314  % plane 5 idx 46
    "ow5_47" % 0 ONEWEB 0287  % plane 5 idx 47
    "ow5_48" % 0 ONEWEB 0627  % plane 5 idx 48
    "ow5_49" % 0 ONEWEB 0442  % plane 5 idx 49
    "ow5_50" % 0 ONEWEB 0687  % plane 5 idx 50
    "ow5_51" % 0 ONEWEB 0623  % plane 5 idx 51
    "ow5_52" % 0 ONEWEB 0391  % plane 5 idx 52
    "ow5_53" % 0 ONEWEB 0410  % plane 5 idx 53
    "ow6_1" % 0 ONEWEB 0060  % plane 6 idx 1
    "ow6_2" % 0 ONEWEB 0038  % plane 6 idx 2
    "ow6_3" % 0 ONEWEB 0690  % plane 6 idx 3
    "ow6_4" % 0 ONEWEB 0028  % plane 6 idx 4
    "ow6_5" % 0 ONEWEB 0086  % plane 6 idx 5
    "ow6_6" % 0 ONEWEB 0067  % plane 6 idx 6
    "ow6_7" % 0 ONEWEB 0087  % plane 6 idx 7
    "ow6_8" % 0 ONEWEB 0698  % plane 6 idx 8
    "ow6_9" % 0 ONEWEB 0093  % plane 6 idx 9
    "ow6_10" % 0 ONEWEB 0082  % plane 6 idx 10
    "ow6_11" % 0 ONEWEB 0066  % plane 6 idx 11
    "ow6_12" % 0 ONEWEB 0018  % plane 6 idx 12
    "ow6_13" % 0 ONEWEB 0080  % plane 6 idx 13
    "ow6_14" % 0 ONEWEB 0081  % plane 6 idx 14
    "ow6_15" % 0 ONEWEB 0096  % plane 6 idx 15
    "ow6_16" % 0 ONEWEB 0068  % plane 6 idx 16
    "ow6_17" % 0 ONEWEB 0045  % plane 6 idx 17
    "ow6_18" % 0 ONEWEB 0029  % plane 6 idx 18
    "ow6_19" % 0 ONEWEB 0061  % plane 6 idx 19
    "ow6_20" % 0 ONEWEB 0069  % plane 6 idx 20
    "ow6_21" % 0 ONEWEB 0019  % plane 6 idx 21
    "ow6_22" % 0 ONEWEB 0691  % plane 6 idx 22
    "ow6_23" % 0 ONEWEB 0621  % plane 6 idx 23
    "ow6_24" % 0 ONEWEB 0034  % plane 6 idx 24
    "ow6_25" % 0 ONEWEB 0055  % plane 6 idx 25
    "ow6_26" % 0 ONEWEB 0083  % plane 6 idx 26
    "ow6_27" % 0 ONEWEB 0088  % plane 6 idx 27
    "ow6_28" % 0 ONEWEB 0098  % plane 6 idx 28
    "ow6_29" % 0 ONEWEB 0042  % plane 6 idx 29
    "ow6_30" % 0 ONEWEB 0031  % plane 6 idx 30
    "ow6_31" % 0 ONEWEB 0090  % plane 6 idx 31
    "ow6_32" % 0 ONEWEB 0085  % plane 6 idx 32
    "ow6_33" % 0 ONEWEB 0598  % plane 6 idx 33
    "ow6_34" % 0 ONEWEB 0051  % plane 6 idx 34
    "ow6_35" % 0 ONEWEB 0026  % plane 6 idx 35
    "ow6_36" % 0 ONEWEB 0037  % plane 6 idx 36
    "ow6_37" % 0 ONEWEB 0064  % plane 6 idx 37
    "ow6_38" % 0 ONEWEB 0015  % plane 6 idx 38
    "ow6_39" % 0 ONEWEB 0541  % plane 6 idx 39
    "ow6_40" % 0 ONEWEB 0399  % plane 6 idx 40
    "ow6_41" % 0 ONEWEB 0046  % plane 6 idx 41
    "ow6_42" % 0 ONEWEB 0063  % plane 6 idx 42
    "ow6_43" % 0 ONEWEB 0620  % plane 6 idx 43
    "ow6_44" % 0 ONEWEB 0697  % plane 6 idx 44
    "ow6_45" % 0 ONEWEB 0709  % plane 6 idx 45
    "ow6_46" % 0 ONEWEB 0692  % plane 6 idx 46
    "ow6_47" % 0 ONEWEB 0092  % plane 6 idx 47
    "ow6_48" % 0 ONEWEB 0404  % plane 6 idx 48
    "ow6_49" % 0 ONEWEB 0395  % plane 6 idx 49
    "ow6_50" % 0 ONEWEB 0614  % plane 6 idx 50
    "ow6_51" % 0 ONEWEB 0713  % plane 6 idx 51
    "ow6_52" % 0 ONEWEB 0398  % plane 6 idx 52
    "ow6_53" % 0 ONEWEB 0702  % plane 6 idx 53
    "ow6_54" % 0 ONEWEB 0689  % plane 6 idx 54
    "ow6_55" % 0 ONEWEB 0617  % plane 6 idx 55
    "ow6_56" % 0 ONEWEB 0409  % plane 6 idx 56
    "ow6_57" % 0 ONEWEB 0695  % plane 6 idx 57
    "ow6_58" % 0 ONEWEB 0715  % plane 6 idx 58
    "ow6_59" % 0 ONEWEB 0711  % plane 6 idx 59
    "ow6_60" % 0 ONEWEB 0095  % plane 6 idx 60
    "ow6_61" % 0 ONEWEB 0622  % plane 6 idx 61
    "ow7_1" % 0 ONEWEB 0039  % plane 7 idx 1
    "ow7_2" % 0 ONEWEB 0053  % plane 7 idx 2
    "ow7_3" % 0 ONEWEB 0435  % plane 7 idx 3
    "ow7_4" % 0 ONEWEB 0036  % plane 7 idx 4
    "ow7_5" % 0 ONEWEB 0474  % plane 7 idx 5
    "ow7_6" % 0 ONEWEB 0468  % plane 7 idx 6
    "ow7_7" % 0 ONEWEB 0464  % plane 7 idx 7
    "ow7_8" % 0 ONEWEB 0025  % plane 7 idx 8
    "ow7_9" % 0 ONEWEB 0021  % plane 7 idx 9
    "ow7_10" % 0 ONEWEB 0428  % plane 7 idx 10
    "ow7_11" % 0 ONEWEB 0456  % plane 7 idx 11
    "ow7_12" % 0 ONEWEB 0473  % plane 7 idx 12
    "ow7_13" % 0 ONEWEB 0458  % plane 7 idx 13
    "ow7_14" % 0 ONEWEB 0058  % plane 7 idx 14
    "ow7_15" % 0 ONEWEB 0044  % plane 7 idx 15
    "ow7_16" % 0 ONEWEB 0439  % plane 7 idx 16
    "ow7_17" % 0 ONEWEB 0032  % plane 7 idx 17
    "ow7_18" % 0 ONEWEB 0444  % plane 7 idx 18
    "ow7_19" % 0 ONEWEB 0059  % plane 7 idx 19
    "ow7_20" % 0 ONEWEB 0043  % plane 7 idx 20
    "ow7_21" % 0 ONEWEB 0047  % plane 7 idx 21
    "ow7_22" % 0 ONEWEB 0062  % plane 7 idx 22
    "ow7_23" % 0 ONEWEB 0017  % plane 7 idx 23
    "ow7_24" % 0 ONEWEB 0024  % plane 7 idx 24
    "ow7_25" % 0 ONEWEB 0035  % plane 7 idx 25
    "ow7_26" % 0 ONEWEB 0057  % plane 7 idx 26
    "ow7_27" % 0 ONEWEB 0033  % plane 7 idx 27
    "ow7_28" % 0 ONEWEB 0048  % plane 7 idx 28
    "ow7_29" % 0 ONEWEB 0438  % plane 7 idx 29
    "ow7_30" % 0 ONEWEB 0431  % plane 7 idx 30
    "ow7_31" % 0 ONEWEB 0699  % plane 7 idx 31
    "ow7_32" % 0 ONEWEB 0425  % plane 7 idx 32
    "ow7_33" % 0 ONEWEB 0415  % plane 7 idx 33
    "ow7_34" % 0 ONEWEB 0701  % plane 7 idx 34
    "ow7_35" % 0 ONEWEB 0449  % plane 7 idx 35
    "ow7_36" % 0 ONEWEB 0411  % plane 7 idx 36
    "ow7_37" % 0 ONEWEB 0023  % plane 7 idx 37
    "ow7_38" % 0 ONEWEB 0056  % plane 7 idx 38
    "ow7_39" % 0 ONEWEB 0445  % plane 7 idx 39
    "ow7_40" % 0 ONEWEB 0020  % plane 7 idx 40
    "ow7_41" % 0 ONEWEB 0054  % plane 7 idx 41
    "ow7_42" % 0 ONEWEB 0065  % plane 7 idx 42
    "ow7_43" % 0 ONEWEB 0457  % plane 7 idx 43
    "ow7_44" % 0 ONEWEB 0707  % plane 7 idx 44
    "ow7_45" % 0 ONEWEB 0049  % plane 7 idx 45
    "ow7_46" % 0 ONEWEB 0704  % plane 7 idx 46
    "ow7_47" % 0 ONEWEB 0052  % plane 7 idx 47
    "ow7_48" % 0 ONEWEB 0706  % plane 7 idx 48
    "ow7_49" % 0 ONEWEB 0708  % plane 7 idx 49
    "ow7_50" % 0 ONEWEB 0700  % plane 7 idx 50
    "ow7_51" % 0 ONEWEB 0705  % plane 7 idx 51
    "ow8_1" % 0 ONEWEB 0448  % plane 8 idx 1
    "ow8_2" % 0 ONEWEB 0040  % plane 8 idx 2
    "ow8_3" % 0 ONEWEB 0416  % plane 8 idx 3
    "ow8_4" % 0 ONEWEB 0446  % plane 8 idx 4
    "ow8_5" % 0 ONEWEB 0434  % plane 8 idx 5
    "ow9_1" % 0 ONEWEB 0013  % plane 9 idx 1
    "ow10_1" % 0 ONEWEB 0721  % plane 10 idx 1
    "ow11_1" % 0 ONEWEB 0050  % plane 11 idx 1
    "ow12_1" % 0 ONEWEB 0618  % plane 12 idx 1
    "ow13_1" % 0 ONEWEB 0250  % plane 13 idx 1
    "ow14_1" % 0 ONEWEB 0712  % plane 14 idx 1
    "ow14_2" % 0 ONEWEB 0261  % plane 14 idx 2
    "ow14_3" % 0 ONEWEB 0279  % plane 14 idx 3
    "ow14_4" % 0 ONEWEB 0263  % plane 14 idx 4
    "ow14_5" % 0 ONEWEB 0548  % plane 14 idx 5
    "ow14_6" % 0 ONEWEB 0272  % plane 14 idx 6
    "ow14_7" % 0 ONEWEB 0274  % plane 14 idx 7
    "ow14_8" % 0 ONEWEB 0271  % plane 14 idx 8
    "ow14_9" % 0 ONEWEB 0277  % plane 14 idx 9
    "ow14_10" % 0 ONEWEB 0267  % plane 14 idx 10
    "ow14_11" % 0 ONEWEB 0264  % plane 14 idx 11
    "ow14_12" % 0 ONEWEB 0010  % plane 14 idx 12
    "ow14_13" % 0 ONEWEB 0252  % plane 14 idx 13
    "ow14_14" % 0 ONEWEB 0270  % plane 14 idx 14
    "ow14_15" % 0 ONEWEB 0581  % plane 14 idx 15
    "ow14_16" % 0 ONEWEB 0012  % plane 14 idx 16
    "ow14_17" % 0 ONEWEB 0260  % plane 14 idx 17
    "ow14_18" % 0 ONEWEB 0257  % plane 14 idx 18
    "ow14_19" % 0 ONEWEB 0254  % plane 14 idx 19
    "ow14_20" % 0 ONEWEB 0253  % plane 14 idx 20
    "ow14_21" % 0 ONEWEB 0283  % plane 14 idx 21
    "ow14_22" % 0 ONEWEB 0255  % plane 14 idx 22
    "ow14_23" % 0 ONEWEB 0273  % plane 14 idx 23
    "ow14_24" % 0 ONEWEB 0676  % plane 14 idx 24
    "ow14_25" % 0 ONEWEB 0282  % plane 14 idx 25
    "ow14_26" % 0 ONEWEB 0259  % plane 14 idx 26
    "ow14_27" % 0 ONEWEB 0275  % plane 14 idx 27
    "ow14_28" % 0 ONEWEB 0249  % plane 14 idx 28
    "ow14_29" % 0 ONEWEB 0554  % plane 14 idx 29
    "ow14_30" % 0 ONEWEB 0268  % plane 14 idx 30
    "ow14_31" % 0 ONEWEB 0281  % plane 14 idx 31
    "ow14_32" % 0 ONEWEB 0256  % plane 14 idx 32
    "ow14_33" % 0 ONEWEB 0262  % plane 14 idx 33
    "ow14_34" % 0 ONEWEB 0276  % plane 14 idx 34
    "ow14_35" % 0 ONEWEB 0538  % plane 14 idx 35
    "ow14_36" % 0 ONEWEB 0280  % plane 14 idx 36
    "ow14_37" % 0 ONEWEB 0258  % plane 14 idx 37
    "ow14_38" % 0 ONEWEB 0269  % plane 14 idx 38
    "ow14_39" % 0 ONEWEB 0266  % plane 14 idx 39
    "ow14_40" % 0 ONEWEB 0278  % plane 14 idx 40
    "ow14_41" % 0 ONEWEB 0577  % plane 14 idx 41
    "ow14_42" % 0 ONEWEB 0576  % plane 14 idx 42
    "ow14_43" % 0 ONEWEB 0686  % plane 14 idx 43
    "ow14_44" % 0 ONEWEB 0008  % plane 14 idx 44
    "ow14_45" % 0 ONEWEB 0284  % plane 14 idx 45
    "ow14_46" % 0 ONEWEB 0575  % plane 14 idx 46
    "ow14_47" % 0 ONEWEB 0537  % plane 14 idx 47
    "ow14_48" % 0 ONEWEB 0568  % plane 14 idx 48
    "ow14_49" % 0 ONEWEB 0553  % plane 14 idx 49
    "ow14_50" % 0 ONEWEB 0668  % plane 14 idx 50
    "ow14_51" % 0 ONEWEB 0694  % plane 14 idx 51
    "ow14_52" % 0 ONEWEB 0679  % plane 14 idx 52
    "ow14_53" % 0 ONEWEB 0555  % plane 14 idx 53
    "ow14_54" % 0 ONEWEB 0546  % plane 14 idx 54
    "ow14_55" % 0 ONEWEB 0557  % plane 14 idx 55
    "ow15_1" % 0 ONEWEB 0593  % plane 15 idx 1
    "ow15_2" % 0 ONEWEB 0681  % plane 15 idx 2
    "ow15_3" % 0 ONEWEB 0602  % plane 15 idx 3
    "ow15_4" % 0 ONEWEB 0545  % plane 15 idx 4
    "ow15_5" % 0 ONEWEB 0655  % plane 15 idx 5
    "ow15_6" % 0 ONEWEB 0552  % plane 15 idx 6
    "ow15_7" % 0 ONEWEB 0559  % plane 15 idx 7
    "ow15_8" % 0 ONEWEB 0579  % plane 15 idx 8
    "ow15_9" % 0 ONEWEB 0539  % plane 15 idx 9
    "ow15_10" % 0 ONEWEB 0566  % plane 15 idx 10
    "ow15_11" % 0 ONEWEB 0604  % plane 15 idx 11
    "ow15_12" % 0 ONEWEB 0540  % plane 15 idx 12
    "ow15_13" % 0 ONEWEB 0714  % plane 15 idx 13
    "ow15_14" % 0 ONEWEB 0600  % plane 15 idx 14
    "ow15_15" % 0 ONEWEB 0558  % plane 15 idx 15
    "ow15_16" % 0 ONEWEB 0611  % plane 15 idx 16
    "ow15_17" % 0 ONEWEB 0583  % plane 15 idx 17
    "ow15_18" % 0 ONEWEB 0547  % plane 15 idx 18
    "ow15_19" % 0 ONEWEB 0542  % plane 15 idx 19
    "ow15_20" % 0 ONEWEB 0549  % plane 15 idx 20
    "ow15_21" % 0 ONEWEB 0594  % plane 15 idx 21
    "ow15_22" % 0 ONEWEB 0586  % plane 15 idx 22
    "ow15_23" % 0 ONEWEB 0528  % plane 15 idx 23
    "ow15_24" % 0 ONEWEB 0603  % plane 15 idx 24
    "ow15_25" % 0 ONEWEB 0607  % plane 15 idx 25
    "ow15_26" % 0 ONEWEB 0574  % plane 15 idx 26
    "ow15_27" % 0 ONEWEB 0527  % plane 15 idx 27
    "ow15_28" % 0 ONEWEB 0615  % plane 15 idx 28
    "ow15_29" % 0 ONEWEB 0550  % plane 15 idx 29
    "ow15_30" % 0 ONEWEB 0685  % plane 15 idx 30
    "ow15_31" % 0 ONEWEB 0612  % plane 15 idx 31
    "ow15_32" % 0 ONEWEB 0597  % plane 15 idx 32
    "ow15_33" % 0 ONEWEB 0582  % plane 15 idx 33
    "ow15_34" % 0 ONEWEB 0601  % plane 15 idx 34
    "ow15_35" % 0 ONEWEB 0606  % plane 15 idx 35
    "ow15_36" % 0 ONEWEB 0585  % plane 15 idx 36
    "ow15_37" % 0 ONEWEB 0580  % plane 15 idx 37
    "ow15_38" % 0 ONEWEB 0659  % plane 15 idx 38
    "ow15_39" % 0 ONEWEB 0587  % plane 15 idx 39
    "ow15_40" % 0 ONEWEB 0595  % plane 15 idx 40
    "ow15_41" % 0 ONEWEB 0592  % plane 15 idx 41
    "ow15_42" % 0 ONEWEB 0591  % plane 15 idx 42
    "ow15_43" % 0 ONEWEB 0596  % plane 15 idx 43
    "ow15_44" % 0 ONEWEB 0610  % plane 15 idx 44
    "ow15_45" % 0 ONEWEB 0608  % plane 15 idx 45
    "ow15_46" % 0 ONEWEB 0584  % plane 15 idx 46
    "ow15_47" % 0 ONEWEB 0578  % plane 15 idx 47
    "ow15_48" % 0 ONEWEB 0589  % plane 15 idx 48
    "ow15_49" % 0 ONEWEB 0590  % plane 15 idx 49
    "ow15_50" % 0 ONEWEB 0605  % plane 15 idx 50
    "ow15_51" % 0 ONEWEB 0680  % plane 15 idx 51
    "ow16_1" % 0 ONEWEB 0703  % plane 16 idx 1
    "ow16_2" % 0 ONEWEB 0247  % plane 16 idx 2
    "ow16_3" % 0 ONEWEB 0210  % plane 16 idx 3
    "ow16_4" % 0 ONEWEB 0190  % plane 16 idx 4
    "ow16_5" % 0 ONEWEB 0684  % plane 16 idx 5
    "ow16_6" % 0 ONEWEB 0214  % plane 16 idx 6
    "ow16_7" % 0 ONEWEB 0225  % plane 16 idx 7
    "ow16_8" % 0 ONEWEB 0215  % plane 16 idx 8
    "ow16_9" % 0 ONEWEB 0243  % plane 16 idx 9
    "ow16_10" % 0 ONEWEB 0235  % plane 16 idx 10
    "ow16_11" % 0 ONEWEB 0226  % plane 16 idx 11
    "ow16_12" % 0 ONEWEB 0696  % plane 16 idx 12
    "ow16_13" % 0 ONEWEB 0678  % plane 16 idx 13
    "ow16_14" % 0 ONEWEB 0223  % plane 16 idx 14
    "ow16_15" % 0 ONEWEB 0007  % plane 16 idx 15
    "ow16_16" % 0 ONEWEB 0231  % plane 16 idx 16
    "ow16_17" % 0 ONEWEB 0237  % plane 16 idx 17
    "ow16_18" % 0 ONEWEB 0213  % plane 16 idx 18
    "ow16_19" % 0 ONEWEB 0630  % plane 16 idx 19
    "ow16_20" % 0 ONEWEB 0216  % plane 16 idx 20
    "ow16_21" % 0 ONEWEB 0246  % plane 16 idx 21
    "ow16_22" % 0 ONEWEB 0239  % plane 16 idx 22
    "ow16_23" % 0 ONEWEB 0242  % plane 16 idx 23
    "ow16_24" % 0 ONEWEB 0221  % plane 16 idx 24
    "ow16_25" % 0 ONEWEB 0613  % plane 16 idx 25
    "ow16_26" % 0 ONEWEB 0233  % plane 16 idx 26
    "ow16_27" % 0 ONEWEB 0647  % plane 16 idx 27
    "ow16_28" % 0 ONEWEB 0006  % plane 16 idx 28
    "ow16_29" % 0 ONEWEB 0229  % plane 16 idx 29
    "ow16_30" % 0 ONEWEB 0632  % plane 16 idx 30
    "ow16_31" % 0 ONEWEB 0551  % plane 16 idx 31
    "ow16_32" % 0 ONEWEB 0633  % plane 16 idx 32
    "ow16_33" % 0 ONEWEB 0248  % plane 16 idx 33
    "ow16_34" % 0 ONEWEB 0244  % plane 16 idx 34
    "ow16_35" % 0 ONEWEB 0228  % plane 16 idx 35
    "ow16_36" % 0 ONEWEB 0241  % plane 16 idx 36
    "ow16_37" % 0 ONEWEB 0635  % plane 16 idx 37
    "ow16_38" % 0 ONEWEB 0222  % plane 16 idx 38
    "ow16_39" % 0 ONEWEB 0211  % plane 16 idx 39
    "ow16_40" % 0 ONEWEB 0227  % plane 16 idx 40
    "ow16_41" % 0 ONEWEB 0636  % plane 16 idx 41
    "ow16_42" % 0 ONEWEB 0230  % plane 16 idx 42
    "ow16_43" % 0 ONEWEB 0240  % plane 16 idx 43
    "ow16_44" % 0 ONEWEB 0232  % plane 16 idx 44
    "ow16_45" % 0 ONEWEB 0609  % plane 16 idx 45
    "ow16_46" % 0 ONEWEB 0245  % plane 16 idx 46
    "ow16_47" % 0 ONEWEB 0212  % plane 16 idx 47
    "ow16_48" % 0 ONEWEB 0651  % plane 16 idx 48
    "ow16_49" % 0 ONEWEB 0236  % plane 16 idx 49
    "ow16_50" % 0 ONEWEB 0011  % plane 16 idx 50
    "ow16_51" % 0 ONEWEB 0224  % plane 16 idx 51
    "ow16_52" % 0 ONEWEB 0634  % plane 16 idx 52
    "ow16_53" % 0 ONEWEB 0683  % plane 16 idx 53
    "ow16_54" % 0 ONEWEB 0238  % plane 16 idx 54
    "ow16_55" % 0 ONEWEB 0637  % plane 16 idx 55
    "ow16_56" % 0 ONEWEB 0718  % plane 16 idx 56
    "ow16_57" % 0 ONEWEB 0682  % plane 16 idx 57
    "ow16_58" % 0 ONEWEB 0234  % plane 16 idx 58
    "ow17_1" % 0 ONEWEB 0368  % plane 17 idx 1
    "ow17_2" % 0 ONEWEB 0334  % plane 17 idx 2
    "ow17_3" % 0 ONEWEB 0556  % plane 17 idx 3
    "ow17_4" % 0 ONEWEB 0561  % plane 17 idx 4
    "ow17_5" % 0 ONEWEB 0663  % plane 17 idx 5
    "ow17_6" % 0 ONEWEB 0347  % plane 17 idx 6
    "ow17_7" % 0 ONEWEB 0356  % plane 17 idx 7
    "ow17_8" % 0 ONEWEB 0563  % plane 17 idx 8
    "ow17_9" % 0 ONEWEB 0384  % plane 17 idx 9
    "ow17_10" % 0 ONEWEB 0664  % plane 17 idx 10
    "ow17_11" % 0 ONEWEB 0667  % plane 17 idx 11
    "ow17_12" % 0 ONEWEB 0338  % plane 17 idx 12
    "ow17_13" % 0 ONEWEB 0351  % plane 17 idx 13
    "ow17_14" % 0 ONEWEB 0534  % plane 17 idx 14
    "ow17_15" % 0 ONEWEB 0342  % plane 17 idx 15
    "ow17_16" % 0 ONEWEB 0321  % plane 17 idx 16
    "ow17_17" % 0 ONEWEB 0372  % plane 17 idx 17
    "ow17_18" % 0 ONEWEB 0386  % plane 17 idx 18
    "ow17_19" % 0 ONEWEB 0382  % plane 17 idx 19
    "ow17_20" % 0 ONEWEB 0367  % plane 17 idx 20
    "ow17_21" % 0 ONEWEB 0364  % plane 17 idx 21
    "ow17_22" % 0 ONEWEB 0385  % plane 17 idx 22
    "ow17_23" % 0 ONEWEB 0349  % plane 17 idx 23
    "ow17_24" % 0 ONEWEB 0361  % plane 17 idx 24
    "ow17_25" % 0 ONEWEB 0363  % plane 17 idx 25
    "ow17_26" % 0 ONEWEB 0378  % plane 17 idx 26
    "ow17_27" % 0 ONEWEB 0357  % plane 17 idx 27
    "ow17_28" % 0 ONEWEB 0677  % plane 17 idx 28
    "ow17_29" % 0 ONEWEB 0358  % plane 17 idx 29
    "ow17_30" % 0 ONEWEB 0373  % plane 17 idx 30
    "ow17_31" % 0 ONEWEB 0360  % plane 17 idx 31
    "ow17_32" % 0 ONEWEB 0564  % plane 17 idx 32
    "ow17_33" % 0 ONEWEB 0562  % plane 17 idx 33
    "ow17_34" % 0 ONEWEB 0381  % plane 17 idx 34
    "ow17_35" % 0 ONEWEB 0377  % plane 17 idx 35
    "ow17_36" % 0 ONEWEB 0370  % plane 17 idx 36
    "ow17_37" % 0 ONEWEB 0672  % plane 17 idx 37
    "ow17_38" % 0 ONEWEB 0354  % plane 17 idx 38
    "ow17_39" % 0 ONEWEB 0387  % plane 17 idx 39
    "ow17_40" % 0 ONEWEB 0656  % plane 17 idx 40
    "ow17_41" % 0 ONEWEB 0530  % plane 17 idx 41
    "ow17_42" % 0 ONEWEB 0669  % plane 17 idx 42
    "ow17_43" % 0 ONEWEB 0375  % plane 17 idx 43
    "ow17_44" % 0 ONEWEB 0359  % plane 17 idx 44
    "ow17_45" % 0 ONEWEB 0524  % plane 17 idx 45
    "ow17_46" % 0 ONEWEB 0510  % plane 17 idx 46
    "ow17_47" % 0 ONEWEB 0515  % plane 17 idx 47
    "ow17_48" % 0 ONEWEB 0348  % plane 17 idx 48
    "ow17_49" % 0 ONEWEB 0666  % plane 17 idx 49
    "ow17_50" % 0 ONEWEB 0531  % plane 17 idx 50
    "ow17_51" % 0 ONEWEB 0536  % plane 17 idx 51
    "ow17_52" % 0 ONEWEB 0523  % plane 17 idx 52
    "ow18_1" % 0 ONEWEB 0640  % plane 18 idx 1
    "ow18_2" % 0 ONEWEB 0648  % plane 18 idx 2
    "ow18_3" % 0 ONEWEB 0193  % plane 18 idx 3
    "ow18_4" % 0 ONEWEB 0674  % plane 18 idx 4
    "ow18_5" % 0 ONEWEB 0670  % plane 18 idx 5
    "ow18_6" % 0 ONEWEB 0661  % plane 18 idx 6
    "ow18_7" % 0 ONEWEB 0660  % plane 18 idx 7
    "ow18_8" % 0 ONEWEB 0662  % plane 18 idx 8
    "ow18_9" % 0 ONEWEB 0638  % plane 18 idx 9
    "ow18_10" % 0 ONEWEB 0665  % plane 18 idx 10
    "ow18_11" % 0 ONEWEB 0206  % plane 18 idx 11
    "ow18_12" % 0 ONEWEB 0353  % plane 18 idx 12
    "ow18_13" % 0 ONEWEB 0184  % plane 18 idx 13
    "ow18_14" % 0 ONEWEB 0374  % plane 18 idx 14
    "ow18_15" % 0 ONEWEB 0194  % plane 18 idx 15
    "ow18_16" % 0 ONEWEB 0332  % plane 18 idx 16
    "ow18_17" % 0 ONEWEB 0203  % plane 18 idx 17
    "ow18_18" % 0 ONEWEB 0653  % plane 18 idx 18
    "ow18_19" % 0 ONEWEB 0383  % plane 18 idx 19
    "ow18_20" % 0 ONEWEB 0199  % plane 18 idx 20
    "ow18_21" % 0 ONEWEB 0379  % plane 18 idx 21
    "ow18_22" % 0 ONEWEB 0218  % plane 18 idx 22
    "ow18_23" % 0 ONEWEB 0191  % plane 18 idx 23
    "ow18_24" % 0 ONEWEB 0176  % plane 18 idx 24
    "ow18_25" % 0 ONEWEB 0366  % plane 18 idx 25
    "ow18_26" % 0 ONEWEB 0643  % plane 18 idx 26
    "ow18_27" % 0 ONEWEB 0192  % plane 18 idx 27
    "ow18_28" % 0 ONEWEB 0188  % plane 18 idx 28
    "ow18_29" % 0 ONEWEB 0217  % plane 18 idx 29
    "ow18_30" % 0 ONEWEB 0200  % plane 18 idx 30
    "ow18_31" % 0 ONEWEB 0208  % plane 18 idx 31
    "ow18_32" % 0 ONEWEB 0202  % plane 18 idx 32
    "ow18_33" % 0 ONEWEB 0196  % plane 18 idx 33
    "ow18_34" % 0 ONEWEB 0181  % plane 18 idx 34
    "ow18_35" % 0 ONEWEB 0204  % plane 18 idx 35
    "ow18_36" % 0 ONEWEB 0195  % plane 18 idx 36
    "ow18_37" % 0 ONEWEB 0179  % plane 18 idx 37
    "ow18_38" % 0 ONEWEB 0205  % plane 18 idx 38
    "ow18_39" % 0 ONEWEB 0186  % plane 18 idx 39
    "ow18_40" % 0 ONEWEB 0189  % plane 18 idx 40
    "ow18_41" % 0 ONEWEB 0182  % plane 18 idx 41
    "ow18_42" % 0 ONEWEB 0652  % plane 18 idx 42
    "ow18_43" % 0 ONEWEB 0180  % plane 18 idx 43
    "ow18_44" % 0 ONEWEB 0165  % plane 18 idx 44
    "ow18_45" % 0 ONEWEB 0183  % plane 18 idx 45
    "ow18_46" % 0 ONEWEB 0198  % plane 18 idx 46
    "ow18_47" % 0 ONEWEB 0197  % plane 18 idx 47
    "ow18_48" % 0 ONEWEB 0207  % plane 18 idx 48
    "ow18_49" % 0 ONEWEB 0209  % plane 18 idx 49
    "ow18_50" % 0 ONEWEB 0654  % plane 18 idx 50
    "ow18_51" % 0 ONEWEB 0187  % plane 18 idx 51
    "ow18_52" % 0 ONEWEB 0220  % plane 18 idx 52
    "ow18_53" % 0 ONEWEB 0219  % plane 18 idx 53
    "ow18_54" % 0 ONEWEB 0201  % plane 18 idx 54
    "ow18_55" % 0 ONEWEB 0185  % plane 18 idx 55
    "ow19_1" % 0 ONEWEB 0513  % plane 19 idx 1
    "ow19_2" % 0 ONEWEB 0495  % plane 19 idx 2
    "ow19_3" % 0 ONEWEB 0505  % plane 19 idx 3
    "ow19_4" % 0 ONEWEB 0639  % plane 19 idx 4
    "ow19_5" % 0 ONEWEB 0645  % plane 19 idx 5
    "ow19_6" % 0 ONEWEB 0512  % plane 19 idx 6
    "ow19_7" % 0 ONEWEB 0501  % plane 19 idx 7
    "ow19_8" % 0 ONEWEB 0649  % plane 19 idx 8
    "ow19_9" % 0 ONEWEB 0504  % plane 19 idx 9
    "ow19_10" % 0 ONEWEB 0502  % plane 19 idx 10
    "ow19_11" % 0 ONEWEB 0508  % plane 19 idx 11
    "ow19_12" % 0 ONEWEB 0525  % plane 19 idx 12
    "ow19_13" % 0 ONEWEB 0720  % plane 19 idx 13
    "ow19_14" % 0 ONEWEB 0520  % plane 19 idx 14
    "ow19_15" % 0 ONEWEB 0642  % plane 19 idx 15
    "ow19_16" % 0 ONEWEB 0499  % plane 19 idx 16
    "ow19_17" % 0 ONEWEB 0507  % plane 19 idx 17
    "ow19_18" % 0 ONEWEB 0506  % plane 19 idx 18
    "ow19_19" % 0 ONEWEB 0671  % plane 19 idx 19
    "ow19_20" % 0 ONEWEB 0522  % plane 19 idx 20
    "ow19_21" % 0 ONEWEB 0529  % plane 19 idx 21
    "ow19_22" % 0 ONEWEB 0376  % plane 19 idx 22
    "ow19_23" % 0 ONEWEB 0518  % plane 19 idx 23
    "ow19_24" % 0 ONEWEB 0490  % plane 19 idx 24
    "ow19_25" % 0 ONEWEB 0644  % plane 19 idx 25
    "ow19_26" % 0 ONEWEB 0380  % plane 19 idx 26
    "ow19_27" % 0 ONEWEB 0511  % plane 19 idx 27
    "ow19_28" % 0 ONEWEB 0658  % plane 19 idx 28
    "ow19_29" % 0 ONEWEB 0641  % plane 19 idx 29
    "ow19_30" % 0 ONEWEB 0509  % plane 19 idx 30
    "ow19_31" % 0 ONEWEB 0369  % plane 19 idx 31
    "ow19_32" % 0 ONEWEB 0646  % plane 19 idx 32
    "ow19_33" % 0 ONEWEB 0365  % plane 19 idx 33
    "ow19_34" % 0 ONEWEB 0519  % plane 19 idx 34
    "ow19_35" % 0 ONEWEB 0650  % plane 19 idx 35
    "ow19_36" % 0 ONEWEB 0497  % plane 19 idx 36
    "ow19_37" % 0 ONEWEB 0516  % plane 19 idx 37
    "ow19_38" % 0 ONEWEB 0517  % plane 19 idx 38
    "ow19_39" % 0 ONEWEB 0673  % plane 19 idx 39
    "ow19_40" % 0 ONEWEB 0503  % plane 19 idx 40
    "ow19_41" % 0 ONEWEB 0526  % plane 19 idx 41
    "ow19_42" % 0 ONEWEB 0388  % plane 19 idx 42
    "ow19_43" % 0 ONEWEB 0492  % plane 19 idx 43
    "ow19_44" % 0 ONEWEB 0371  % plane 19 idx 44
    "ow19_45" % 0 ONEWEB 0362  % plane 19 idx 45
    "ow19_46" % 0 ONEWEB 0521  % plane 19 idx 46
    "ow19_47" % 0 ONEWEB 0500  % plane 19 idx 47
    "ow19_48" % 0 ONEWEB 0514  % plane 19 idx 48
    "ow19_49" % 0 ONEWEB 0675  % plane 19 idx 49
    "ow19_50" % 0 ONEWEB 0535  % plane 19 idx 50
    "ow19_51" % 0 ONEWEB 0657  % plane 19 idx 51
];

OneWeb_OMNet_leo_part = [
    
];

OneWeb_leo = [
    "ONEWEB_0160" % plane 1 idx 1
    "ONEWEB_0170" % plane 1 idx 2
    "ONEWEB_0158" % plane 1 idx 3
    "ONEWEB_0322" % plane 1 idx 4
    "ONEWEB_0175" % plane 1 idx 5
    "ONEWEB_0152" % plane 1 idx 6
    "ONEWEB_0116" % plane 1 idx 7
    "ONEWEB_0352" % plane 1 idx 8
    "ONEWEB_0113" % plane 1 idx 9
    "ONEWEB_0333" % plane 1 idx 10
    "ONEWEB_0164" % plane 1 idx 11
    "ONEWEB_0569" % plane 1 idx 12
    "ONEWEB_0115" % plane 1 idx 13
    "ONEWEB_0154" % plane 1 idx 14
    "ONEWEB_0108" % plane 1 idx 15
    "ONEWEB_0171" % plane 1 idx 16
    "ONEWEB_0169" % plane 1 idx 17
    "ONEWEB_0151" % plane 1 idx 18
    "ONEWEB_0307" % plane 1 idx 19
    "ONEWEB_0155" % plane 1 idx 20
    "ONEWEB_0339" % plane 1 idx 21
    "ONEWEB_0101" % plane 1 idx 22
    "ONEWEB_0172" % plane 1 idx 23
    "ONEWEB_0178" % plane 1 idx 24
    "ONEWEB_0167" % plane 1 idx 25
    "ONEWEB_0153" % plane 1 idx 26
    "ONEWEB_0112" % plane 1 idx 27
    "ONEWEB_0292" % plane 1 idx 28
    "ONEWEB_0335" % plane 1 idx 29
    "ONEWEB_0355" % plane 1 idx 30
    "ONEWEB_0162" % plane 1 idx 31
    "ONEWEB_0156" % plane 1 idx 32
    "ONEWEB_0150" % plane 1 idx 33
    "ONEWEB_0328" % plane 1 idx 34
    "ONEWEB_0149" % plane 1 idx 35
    "ONEWEB_0161" % plane 1 idx 36
    "ONEWEB_0177" % plane 1 idx 37
    "ONEWEB_0174" % plane 1 idx 38
    "ONEWEB_0168" % plane 1 idx 39
    "ONEWEB_0166" % plane 1 idx 40
    "ONEWEB_0163" % plane 1 idx 41
    "ONEWEB_0337" % plane 1 idx 42
    "ONEWEB_0173" % plane 1 idx 43
    "ONEWEB_0107" % plane 1 idx 44
    "ONEWEB_0159" % plane 1 idx 45
    "ONEWEB_0350" % plane 1 idx 46
    "ONEWEB_0345" % plane 1 idx 47
    "ONEWEB_0157" % plane 1 idx 48
    "ONEWEB_0336" % plane 1 idx 49
    "ONEWEB_0344" % plane 1 idx 50
    "ONEWEB_0148" % plane 1 idx 51
    "ONEWEB_0402" % plane 2 idx 1
    "ONEWEB_0440" % plane 2 idx 2
    "ONEWEB_0412" % plane 2 idx 3
    "ONEWEB_0405" % plane 2 idx 4
    "ONEWEB_0421" % plane 2 idx 5
    "ONEWEB_0420" % plane 2 idx 6
    "ONEWEB_0401" % plane 2 idx 7
    "ONEWEB_0414" % plane 2 idx 8
    "ONEWEB_0426" % plane 2 idx 9
    "ONEWEB_0327" % plane 2 idx 10
    "ONEWEB_0397" % plane 2 idx 11
    "ONEWEB_0450" % plane 2 idx 12
    "ONEWEB_0560" % plane 2 idx 13
    "ONEWEB_0429" % plane 2 idx 14
    "ONEWEB_0306" % plane 2 idx 15
    "ONEWEB_0325" % plane 2 idx 16
    "ONEWEB_0396" % plane 2 idx 17
    "ONEWEB_0394" % plane 2 idx 18
    "ONEWEB_0326" % plane 2 idx 19
    "ONEWEB_0340" % plane 2 idx 20
    "ONEWEB_0318" % plane 2 idx 21
    "ONEWEB_0303" % plane 2 idx 22
    "ONEWEB_0400" % plane 2 idx 23
    "ONEWEB_0419" % plane 2 idx 24
    "ONEWEB_0346" % plane 2 idx 25
    "ONEWEB_0320" % plane 2 idx 26
    "ONEWEB_0324" % plane 2 idx 27
    "ONEWEB_0343" % plane 2 idx 28
    "ONEWEB_0427" % plane 2 idx 29
    "ONEWEB_0417" % plane 2 idx 30
    "ONEWEB_0331" % plane 2 idx 31
    "ONEWEB_0424" % plane 2 idx 32
    "ONEWEB_0631" % plane 2 idx 33
    "ONEWEB_0418" % plane 2 idx 34
    "ONEWEB_0406" % plane 2 idx 35
    "ONEWEB_0432" % plane 2 idx 36
    "ONEWEB_0413" % plane 3 idx 1
    "ONEWEB_0543" % plane 3 idx 2
    "ONEWEB_0407" % plane 3 idx 3
    "ONEWEB_0544" % plane 3 idx 4
    "ONEWEB_0316" % plane 3 idx 5
    "ONEWEB_0430" % plane 3 idx 6
    "ONEWEB_0403" % plane 3 idx 7
    "ONEWEB_0341" % plane 3 idx 8
    "ONEWEB_0567" % plane 3 idx 9
    "ONEWEB_0565" % plane 3 idx 10
    "ONEWEB_0571" % plane 3 idx 11
    "ONEWEB_0588" % plane 3 idx 12
    "ONEWEB_0570" % plane 3 idx 13
    "ONEWEB_0573" % plane 3 idx 14
    "ONEWEB_0301" % plane 4 idx 1
    "ONEWEB_0146" % plane 4 idx 2
    "ONEWEB_0300" % plane 4 idx 3
    "ONEWEB_0110" % plane 4 idx 4
    "ONEWEB_0135" % plane 4 idx 5
    "ONEWEB_0124" % plane 4 idx 6
    "ONEWEB_0121" % plane 4 idx 7
    "ONEWEB_0533" % plane 4 idx 8
    "ONEWEB_0133" % plane 4 idx 9
    "ONEWEB_0128" % plane 4 idx 10
    "ONEWEB_0147" % plane 4 idx 11
    "ONEWEB_0131" % plane 4 idx 12
    "ONEWEB_0117" % plane 4 idx 13
    "ONEWEB_0130" % plane 4 idx 14
    "ONEWEB_0138" % plane 4 idx 15
    "ONEWEB_0308" % plane 4 idx 16
    "ONEWEB_0122" % plane 4 idx 17
    "ONEWEB_0140" % plane 4 idx 18
    "ONEWEB_0317" % plane 4 idx 19
    "ONEWEB_0119" % plane 4 idx 20
    "ONEWEB_0132" % plane 4 idx 21
    "ONEWEB_0143" % plane 4 idx 22
    "ONEWEB_0136" % plane 4 idx 23
    "ONEWEB_0139" % plane 4 idx 24
    "ONEWEB_0285" % plane 4 idx 25
    "ONEWEB_0111" % plane 4 idx 26
    "ONEWEB_0123" % plane 4 idx 27
    "ONEWEB_0134" % plane 4 idx 28
    "ONEWEB_0145" % plane 4 idx 29
    "ONEWEB_0125" % plane 4 idx 30
    "ONEWEB_0109" % plane 4 idx 31
    "ONEWEB_0127" % plane 4 idx 32
    "ONEWEB_0297" % plane 4 idx 33
    "ONEWEB_0126" % plane 4 idx 34
    "ONEWEB_0310" % plane 4 idx 35
    "ONEWEB_0286" % plane 4 idx 36
    "ONEWEB_0102" % plane 4 idx 37
    "ONEWEB_0120" % plane 4 idx 38
    "ONEWEB_0315" % plane 4 idx 39
    "ONEWEB_0144" % plane 4 idx 40
    "ONEWEB_0288" % plane 4 idx 41
    "ONEWEB_0137" % plane 4 idx 42
    "ONEWEB_0628" % plane 4 idx 43
    "ONEWEB_0294" % plane 4 idx 44
    "ONEWEB_0302" % plane 4 idx 45
    "ONEWEB_0114" % plane 4 idx 46
    "ONEWEB_0624" % plane 4 idx 47
    "ONEWEB_0141" % plane 4 idx 48
    "ONEWEB_0118" % plane 4 idx 49
    "ONEWEB_0142" % plane 4 idx 50
    "ONEWEB_0296" % plane 4 idx 51
    "ONEWEB_0323" % plane 4 idx 52
    "ONEWEB_0129" % plane 4 idx 53
    "ONEWEB_0693" % plane 5 idx 1
    "ONEWEB_0475" % plane 5 idx 2
    "ONEWEB_0616" % plane 5 idx 3
    "ONEWEB_0422" % plane 5 idx 4
    "ONEWEB_0629" % plane 5 idx 5
    "ONEWEB_0619" % plane 5 idx 6
    "ONEWEB_0719" % plane 5 idx 7
    "ONEWEB_0716" % plane 5 idx 8
    "ONEWEB_0452" % plane 5 idx 9
    "ONEWEB_0625" % plane 5 idx 10
    "ONEWEB_0443" % plane 5 idx 11
    "ONEWEB_0436" % plane 5 idx 12
    "ONEWEB_0423" % plane 5 idx 13
    "ONEWEB_0298" % plane 5 idx 14
    "ONEWEB_0094" % plane 5 idx 15
    "ONEWEB_0463" % plane 5 idx 16
    "ONEWEB_0599" % plane 5 idx 17
    "ONEWEB_0451" % plane 5 idx 18
    "ONEWEB_0290" % plane 5 idx 19
    "ONEWEB_0389" % plane 5 idx 20
    "ONEWEB_0293" % plane 5 idx 21
    "ONEWEB_0299" % plane 5 idx 22
    "ONEWEB_0393" % plane 5 idx 23
    "ONEWEB_0313" % plane 5 idx 24
    "ONEWEB_0295" % plane 5 idx 25
    "ONEWEB_0304" % plane 5 idx 26
    "ONEWEB_0329" % plane 5 idx 27
    "ONEWEB_0461" % plane 5 idx 28
    "ONEWEB_0710" % plane 5 idx 29
    "ONEWEB_0626" % plane 5 idx 30
    "ONEWEB_0572" % plane 5 idx 31
    "ONEWEB_0289" % plane 5 idx 32
    "ONEWEB_0311" % plane 5 idx 33
    "ONEWEB_0390" % plane 5 idx 34
    "ONEWEB_0330" % plane 5 idx 35
    "ONEWEB_0392" % plane 5 idx 36
    "ONEWEB_0309" % plane 5 idx 37
    "ONEWEB_0319" % plane 5 idx 38
    "ONEWEB_0027" % plane 5 idx 39
    "ONEWEB_0717" % plane 5 idx 40
    "ONEWEB_0312" % plane 5 idx 41
    "ONEWEB_0291" % plane 5 idx 42
    "ONEWEB_0305" % plane 5 idx 43
    "ONEWEB_0532" % plane 5 idx 44
    "ONEWEB_0688" % plane 5 idx 45
    "ONEWEB_0314" % plane 5 idx 46
    "ONEWEB_0287" % plane 5 idx 47
    "ONEWEB_0627" % plane 5 idx 48
    "ONEWEB_0442" % plane 5 idx 49
    "ONEWEB_0687" % plane 5 idx 50
    "ONEWEB_0623" % plane 5 idx 51
    "ONEWEB_0391" % plane 5 idx 52
    "ONEWEB_0410" % plane 5 idx 53
    "ONEWEB_0060" % plane 6 idx 1
    "ONEWEB_0038" % plane 6 idx 2
    "ONEWEB_0690" % plane 6 idx 3
    "ONEWEB_0028" % plane 6 idx 4
    "ONEWEB_0086" % plane 6 idx 5
    "ONEWEB_0067" % plane 6 idx 6
    "ONEWEB_0087" % plane 6 idx 7
    "ONEWEB_0698" % plane 6 idx 8
    "ONEWEB_0093" % plane 6 idx 9
    "ONEWEB_0082" % plane 6 idx 10
    "ONEWEB_0066" % plane 6 idx 11
    "ONEWEB_0018" % plane 6 idx 12
    "ONEWEB_0080" % plane 6 idx 13
    "ONEWEB_0081" % plane 6 idx 14
    "ONEWEB_0096" % plane 6 idx 15
    "ONEWEB_0068" % plane 6 idx 16
    "ONEWEB_0045" % plane 6 idx 17
    "ONEWEB_0029" % plane 6 idx 18
    "ONEWEB_0061" % plane 6 idx 19
    "ONEWEB_0069" % plane 6 idx 20
    "ONEWEB_0019" % plane 6 idx 21
    "ONEWEB_0691" % plane 6 idx 22
    "ONEWEB_0621" % plane 6 idx 23
    "ONEWEB_0034" % plane 6 idx 24
    "ONEWEB_0055" % plane 6 idx 25
    "ONEWEB_0083" % plane 6 idx 26
    "ONEWEB_0088" % plane 6 idx 27
    "ONEWEB_0098" % plane 6 idx 28
    "ONEWEB_0042" % plane 6 idx 29
    "ONEWEB_0031" % plane 6 idx 30
    "ONEWEB_0090" % plane 6 idx 31
    "ONEWEB_0085" % plane 6 idx 32
    "ONEWEB_0598" % plane 6 idx 33
    "ONEWEB_0051" % plane 6 idx 34
    "ONEWEB_0026" % plane 6 idx 35
    "ONEWEB_0037" % plane 6 idx 36
    "ONEWEB_0064" % plane 6 idx 37
    "ONEWEB_0015" % plane 6 idx 38
    "ONEWEB_0541" % plane 6 idx 39
    "ONEWEB_0399" % plane 6 idx 40
    "ONEWEB_0046" % plane 6 idx 41
    "ONEWEB_0063" % plane 6 idx 42
    "ONEWEB_0620" % plane 6 idx 43
    "ONEWEB_0697" % plane 6 idx 44
    "ONEWEB_0709" % plane 6 idx 45
    "ONEWEB_0692" % plane 6 idx 46
    "ONEWEB_0092" % plane 6 idx 47
    "ONEWEB_0404" % plane 6 idx 48
    "ONEWEB_0395" % plane 6 idx 49
    "ONEWEB_0614" % plane 6 idx 50
    "ONEWEB_0713" % plane 6 idx 51
    "ONEWEB_0398" % plane 6 idx 52
    "ONEWEB_0702" % plane 6 idx 53
    "ONEWEB_0689" % plane 6 idx 54
    "ONEWEB_0617" % plane 6 idx 55
    "ONEWEB_0409" % plane 6 idx 56
    "ONEWEB_0695" % plane 6 idx 57
    "ONEWEB_0715" % plane 6 idx 58
    "ONEWEB_0711" % plane 6 idx 59
    "ONEWEB_0095" % plane 6 idx 60
    "ONEWEB_0622" % plane 6 idx 61
    "ONEWEB_0039" % plane 7 idx 1
    "ONEWEB_0053" % plane 7 idx 2
    "ONEWEB_0435" % plane 7 idx 3
    "ONEWEB_0036" % plane 7 idx 4
    "ONEWEB_0474" % plane 7 idx 5
    "ONEWEB_0468" % plane 7 idx 6
    "ONEWEB_0464" % plane 7 idx 7
    "ONEWEB_0025" % plane 7 idx 8
    "ONEWEB_0021" % plane 7 idx 9
    "ONEWEB_0428" % plane 7 idx 10
    "ONEWEB_0456" % plane 7 idx 11
    "ONEWEB_0473" % plane 7 idx 12
    "ONEWEB_0458" % plane 7 idx 13
    "ONEWEB_0058" % plane 7 idx 14
    "ONEWEB_0044" % plane 7 idx 15
    "ONEWEB_0439" % plane 7 idx 16
    "ONEWEB_0032" % plane 7 idx 17
    "ONEWEB_0444" % plane 7 idx 18
    "ONEWEB_0059" % plane 7 idx 19
    "ONEWEB_0043" % plane 7 idx 20
    "ONEWEB_0047" % plane 7 idx 21
    "ONEWEB_0062" % plane 7 idx 22
    "ONEWEB_0017" % plane 7 idx 23
    "ONEWEB_0024" % plane 7 idx 24
    "ONEWEB_0035" % plane 7 idx 25
    "ONEWEB_0057" % plane 7 idx 26
    "ONEWEB_0033" % plane 7 idx 27
    "ONEWEB_0048" % plane 7 idx 28
    "ONEWEB_0438" % plane 7 idx 29
    "ONEWEB_0431" % plane 7 idx 30
    "ONEWEB_0699" % plane 7 idx 31
    "ONEWEB_0425" % plane 7 idx 32
    "ONEWEB_0415" % plane 7 idx 33
    "ONEWEB_0701" % plane 7 idx 34
    "ONEWEB_0449" % plane 7 idx 35
    "ONEWEB_0411" % plane 7 idx 36
    "ONEWEB_0023" % plane 7 idx 37
    "ONEWEB_0056" % plane 7 idx 38
    "ONEWEB_0445" % plane 7 idx 39
    "ONEWEB_0020" % plane 7 idx 40
    "ONEWEB_0054" % plane 7 idx 41
    "ONEWEB_0065" % plane 7 idx 42
    "ONEWEB_0457" % plane 7 idx 43
    "ONEWEB_0707" % plane 7 idx 44
    "ONEWEB_0049" % plane 7 idx 45
    "ONEWEB_0704" % plane 7 idx 46
    "ONEWEB_0052" % plane 7 idx 47
    "ONEWEB_0706" % plane 7 idx 48
    "ONEWEB_0708" % plane 7 idx 49
    "ONEWEB_0700" % plane 7 idx 50
    "ONEWEB_0705" % plane 7 idx 51
    "ONEWEB_0448" % plane 8 idx 1
    "ONEWEB_0040" % plane 8 idx 2
    "ONEWEB_0416" % plane 8 idx 3
    "ONEWEB_0446" % plane 8 idx 4
    "ONEWEB_0434" % plane 8 idx 5
    "ONEWEB_0013" % plane 9 idx 1
    "ONEWEB_0721" % plane 10 idx 1
    "ONEWEB_0050" % plane 11 idx 1
    "ONEWEB_0618" % plane 12 idx 1
    "ONEWEB_0250" % plane 13 idx 1
    "ONEWEB_0712" % plane 14 idx 1
    "ONEWEB_0261" % plane 14 idx 2
    "ONEWEB_0279" % plane 14 idx 3
    "ONEWEB_0263" % plane 14 idx 4
    "ONEWEB_0548" % plane 14 idx 5
    "ONEWEB_0272" % plane 14 idx 6
    "ONEWEB_0274" % plane 14 idx 7
    "ONEWEB_0271" % plane 14 idx 8
    "ONEWEB_0277" % plane 14 idx 9
    "ONEWEB_0267" % plane 14 idx 10
    "ONEWEB_0264" % plane 14 idx 11
    "ONEWEB_0010" % plane 14 idx 12
    "ONEWEB_0252" % plane 14 idx 13
    "ONEWEB_0270" % plane 14 idx 14
    "ONEWEB_0581" % plane 14 idx 15
    "ONEWEB_0012" % plane 14 idx 16
    "ONEWEB_0260" % plane 14 idx 17
    "ONEWEB_0257" % plane 14 idx 18
    "ONEWEB_0254" % plane 14 idx 19
    "ONEWEB_0253" % plane 14 idx 20
    "ONEWEB_0283" % plane 14 idx 21
    "ONEWEB_0255" % plane 14 idx 22
    "ONEWEB_0273" % plane 14 idx 23
    "ONEWEB_0676" % plane 14 idx 24
    "ONEWEB_0282" % plane 14 idx 25
    "ONEWEB_0259" % plane 14 idx 26
    "ONEWEB_0275" % plane 14 idx 27
    "ONEWEB_0249" % plane 14 idx 28
    "ONEWEB_0554" % plane 14 idx 29
    "ONEWEB_0268" % plane 14 idx 30
    "ONEWEB_0281" % plane 14 idx 31
    "ONEWEB_0256" % plane 14 idx 32
    "ONEWEB_0262" % plane 14 idx 33
    "ONEWEB_0276" % plane 14 idx 34
    "ONEWEB_0538" % plane 14 idx 35
    "ONEWEB_0280" % plane 14 idx 36
    "ONEWEB_0258" % plane 14 idx 37
    "ONEWEB_0269" % plane 14 idx 38
    "ONEWEB_0266" % plane 14 idx 39
    "ONEWEB_0278" % plane 14 idx 40
    "ONEWEB_0577" % plane 14 idx 41
    "ONEWEB_0576" % plane 14 idx 42
    "ONEWEB_0686" % plane 14 idx 43
    "ONEWEB_0008" % plane 14 idx 44
    "ONEWEB_0284" % plane 14 idx 45
    "ONEWEB_0575" % plane 14 idx 46
    "ONEWEB_0537" % plane 14 idx 47
    "ONEWEB_0568" % plane 14 idx 48
    "ONEWEB_0553" % plane 14 idx 49
    "ONEWEB_0668" % plane 14 idx 50
    "ONEWEB_0694" % plane 14 idx 51
    "ONEWEB_0679" % plane 14 idx 52
    "ONEWEB_0555" % plane 14 idx 53
    "ONEWEB_0546" % plane 14 idx 54
    "ONEWEB_0557" % plane 14 idx 55
    "ONEWEB_0593" % plane 15 idx 1
    "ONEWEB_0681" % plane 15 idx 2
    "ONEWEB_0602" % plane 15 idx 3
    "ONEWEB_0545" % plane 15 idx 4
    "ONEWEB_0655" % plane 15 idx 5
    "ONEWEB_0552" % plane 15 idx 6
    "ONEWEB_0559" % plane 15 idx 7
    "ONEWEB_0579" % plane 15 idx 8
    "ONEWEB_0539" % plane 15 idx 9
    "ONEWEB_0566" % plane 15 idx 10
    "ONEWEB_0604" % plane 15 idx 11
    "ONEWEB_0540" % plane 15 idx 12
    "ONEWEB_0714" % plane 15 idx 13
    "ONEWEB_0600" % plane 15 idx 14
    "ONEWEB_0558" % plane 15 idx 15
    "ONEWEB_0611" % plane 15 idx 16
    "ONEWEB_0583" % plane 15 idx 17
    "ONEWEB_0547" % plane 15 idx 18
    "ONEWEB_0542" % plane 15 idx 19
    "ONEWEB_0549" % plane 15 idx 20
    "ONEWEB_0594" % plane 15 idx 21
    "ONEWEB_0586" % plane 15 idx 22
    "ONEWEB_0528" % plane 15 idx 23
    "ONEWEB_0603" % plane 15 idx 24
    "ONEWEB_0607" % plane 15 idx 25
    "ONEWEB_0574" % plane 15 idx 26
    "ONEWEB_0527" % plane 15 idx 27
    "ONEWEB_0615" % plane 15 idx 28
    "ONEWEB_0550" % plane 15 idx 29
    "ONEWEB_0685" % plane 15 idx 30
    "ONEWEB_0612" % plane 15 idx 31
    "ONEWEB_0597" % plane 15 idx 32
    "ONEWEB_0582" % plane 15 idx 33
    "ONEWEB_0601" % plane 15 idx 34
    "ONEWEB_0606" % plane 15 idx 35
    "ONEWEB_0585" % plane 15 idx 36
    "ONEWEB_0580" % plane 15 idx 37
    "ONEWEB_0659" % plane 15 idx 38
    "ONEWEB_0587" % plane 15 idx 39
    "ONEWEB_0595" % plane 15 idx 40
    "ONEWEB_0592" % plane 15 idx 41
    "ONEWEB_0591" % plane 15 idx 42
    "ONEWEB_0596" % plane 15 idx 43
    "ONEWEB_0610" % plane 15 idx 44
    "ONEWEB_0608" % plane 15 idx 45
    "ONEWEB_0584" % plane 15 idx 46
    "ONEWEB_0578" % plane 15 idx 47
    "ONEWEB_0589" % plane 15 idx 48
    "ONEWEB_0590" % plane 15 idx 49
    "ONEWEB_0605" % plane 15 idx 50
    "ONEWEB_0680" % plane 15 idx 51
    "ONEWEB_0703" % plane 16 idx 1
    "ONEWEB_0247" % plane 16 idx 2
    "ONEWEB_0210" % plane 16 idx 3
    "ONEWEB_0190" % plane 16 idx 4
    "ONEWEB_0684" % plane 16 idx 5
    "ONEWEB_0214" % plane 16 idx 6
    "ONEWEB_0225" % plane 16 idx 7
    "ONEWEB_0215" % plane 16 idx 8
    "ONEWEB_0243" % plane 16 idx 9
    "ONEWEB_0235" % plane 16 idx 10
    "ONEWEB_0226" % plane 16 idx 11
    "ONEWEB_0696" % plane 16 idx 12
    "ONEWEB_0678" % plane 16 idx 13
    "ONEWEB_0223" % plane 16 idx 14
    "ONEWEB_0007" % plane 16 idx 15
    "ONEWEB_0231" % plane 16 idx 16
    "ONEWEB_0237" % plane 16 idx 17
    "ONEWEB_0213" % plane 16 idx 18
    "ONEWEB_0630" % plane 16 idx 19
    "ONEWEB_0216" % plane 16 idx 20
    "ONEWEB_0246" % plane 16 idx 21
    "ONEWEB_0239" % plane 16 idx 22
    "ONEWEB_0242" % plane 16 idx 23
    "ONEWEB_0221" % plane 16 idx 24
    "ONEWEB_0613" % plane 16 idx 25
    "ONEWEB_0233" % plane 16 idx 26
    "ONEWEB_0647" % plane 16 idx 27
    "ONEWEB_0006" % plane 16 idx 28
    "ONEWEB_0229" % plane 16 idx 29
    "ONEWEB_0632" % plane 16 idx 30
    "ONEWEB_0551" % plane 16 idx 31
    "ONEWEB_0633" % plane 16 idx 32
    "ONEWEB_0248" % plane 16 idx 33
    "ONEWEB_0244" % plane 16 idx 34
    "ONEWEB_0228" % plane 16 idx 35
    "ONEWEB_0241" % plane 16 idx 36
    "ONEWEB_0635" % plane 16 idx 37
    "ONEWEB_0222" % plane 16 idx 38
    "ONEWEB_0211" % plane 16 idx 39
    "ONEWEB_0227" % plane 16 idx 40
    "ONEWEB_0636" % plane 16 idx 41
    "ONEWEB_0230" % plane 16 idx 42
    "ONEWEB_0240" % plane 16 idx 43
    "ONEWEB_0232" % plane 16 idx 44
    "ONEWEB_0609" % plane 16 idx 45
    "ONEWEB_0245" % plane 16 idx 46
    "ONEWEB_0212" % plane 16 idx 47
    "ONEWEB_0651" % plane 16 idx 48
    "ONEWEB_0236" % plane 16 idx 49
    "ONEWEB_0011" % plane 16 idx 50
    "ONEWEB_0224" % plane 16 idx 51
    "ONEWEB_0634" % plane 16 idx 52
    "ONEWEB_0683" % plane 16 idx 53
    "ONEWEB_0238" % plane 16 idx 54
    "ONEWEB_0637" % plane 16 idx 55
    "ONEWEB_0718" % plane 16 idx 56
    "ONEWEB_0682" % plane 16 idx 57
    "ONEWEB_0234" % plane 16 idx 58
    "ONEWEB_0368" % plane 17 idx 1
    "ONEWEB_0334" % plane 17 idx 2
    "ONEWEB_0556" % plane 17 idx 3
    "ONEWEB_0561" % plane 17 idx 4
    "ONEWEB_0663" % plane 17 idx 5
    "ONEWEB_0347" % plane 17 idx 6
    "ONEWEB_0356" % plane 17 idx 7
    "ONEWEB_0563" % plane 17 idx 8
    "ONEWEB_0384" % plane 17 idx 9
    "ONEWEB_0664" % plane 17 idx 10
    "ONEWEB_0667" % plane 17 idx 11
    "ONEWEB_0338" % plane 17 idx 12
    "ONEWEB_0351" % plane 17 idx 13
    "ONEWEB_0534" % plane 17 idx 14
    "ONEWEB_0342" % plane 17 idx 15
    "ONEWEB_0321" % plane 17 idx 16
    "ONEWEB_0372" % plane 17 idx 17
    "ONEWEB_0386" % plane 17 idx 18
    "ONEWEB_0382" % plane 17 idx 19
    "ONEWEB_0367" % plane 17 idx 20
    "ONEWEB_0364" % plane 17 idx 21
    "ONEWEB_0385" % plane 17 idx 22
    "ONEWEB_0349" % plane 17 idx 23
    "ONEWEB_0361" % plane 17 idx 24
    "ONEWEB_0363" % plane 17 idx 25
    "ONEWEB_0378" % plane 17 idx 26
    "ONEWEB_0357" % plane 17 idx 27
    "ONEWEB_0677" % plane 17 idx 28
    "ONEWEB_0358" % plane 17 idx 29
    "ONEWEB_0373" % plane 17 idx 30
    "ONEWEB_0360" % plane 17 idx 31
    "ONEWEB_0564" % plane 17 idx 32
    "ONEWEB_0562" % plane 17 idx 33
    "ONEWEB_0381" % plane 17 idx 34
    "ONEWEB_0377" % plane 17 idx 35
    "ONEWEB_0370" % plane 17 idx 36
    "ONEWEB_0672" % plane 17 idx 37
    "ONEWEB_0354" % plane 17 idx 38
    "ONEWEB_0387" % plane 17 idx 39
    "ONEWEB_0656" % plane 17 idx 40
    "ONEWEB_0530" % plane 17 idx 41
    "ONEWEB_0669" % plane 17 idx 42
    "ONEWEB_0375" % plane 17 idx 43
    "ONEWEB_0359" % plane 17 idx 44
    "ONEWEB_0524" % plane 17 idx 45
    "ONEWEB_0510" % plane 17 idx 46
    "ONEWEB_0515" % plane 17 idx 47
    "ONEWEB_0348" % plane 17 idx 48
    "ONEWEB_0666" % plane 17 idx 49
    "ONEWEB_0531" % plane 17 idx 50
    "ONEWEB_0536" % plane 17 idx 51
    "ONEWEB_0523" % plane 17 idx 52
    "ONEWEB_0640" % plane 18 idx 1
    "ONEWEB_0648" % plane 18 idx 2
    "ONEWEB_0193" % plane 18 idx 3
    "ONEWEB_0674" % plane 18 idx 4
    "ONEWEB_0670" % plane 18 idx 5
    "ONEWEB_0661" % plane 18 idx 6
    "ONEWEB_0660" % plane 18 idx 7
    "ONEWEB_0662" % plane 18 idx 8
    "ONEWEB_0638" % plane 18 idx 9
    "ONEWEB_0665" % plane 18 idx 10
    "ONEWEB_0206" % plane 18 idx 11
    "ONEWEB_0353" % plane 18 idx 12
    "ONEWEB_0184" % plane 18 idx 13
    "ONEWEB_0374" % plane 18 idx 14
    "ONEWEB_0194" % plane 18 idx 15
    "ONEWEB_0332" % plane 18 idx 16
    "ONEWEB_0203" % plane 18 idx 17
    "ONEWEB_0653" % plane 18 idx 18
    "ONEWEB_0383" % plane 18 idx 19
    "ONEWEB_0199" % plane 18 idx 20
    "ONEWEB_0379" % plane 18 idx 21
    "ONEWEB_0218" % plane 18 idx 22
    "ONEWEB_0191" % plane 18 idx 23
    "ONEWEB_0176" % plane 18 idx 24
    "ONEWEB_0366" % plane 18 idx 25
    "ONEWEB_0643" % plane 18 idx 26
    "ONEWEB_0192" % plane 18 idx 27
    "ONEWEB_0188" % plane 18 idx 28
    "ONEWEB_0217" % plane 18 idx 29
    "ONEWEB_0200" % plane 18 idx 30
    "ONEWEB_0208" % plane 18 idx 31
    "ONEWEB_0202" % plane 18 idx 32
    "ONEWEB_0196" % plane 18 idx 33
    "ONEWEB_0181" % plane 18 idx 34
    "ONEWEB_0204" % plane 18 idx 35
    "ONEWEB_0195" % plane 18 idx 36
    "ONEWEB_0179" % plane 18 idx 37
    "ONEWEB_0205" % plane 18 idx 38
    "ONEWEB_0186" % plane 18 idx 39
    "ONEWEB_0189" % plane 18 idx 40
    "ONEWEB_0182" % plane 18 idx 41
    "ONEWEB_0652" % plane 18 idx 42
    "ONEWEB_0180" % plane 18 idx 43
    "ONEWEB_0165" % plane 18 idx 44
    "ONEWEB_0183" % plane 18 idx 45
    "ONEWEB_0198" % plane 18 idx 46
    "ONEWEB_0197" % plane 18 idx 47
    "ONEWEB_0207" % plane 18 idx 48
    "ONEWEB_0209" % plane 18 idx 49
    "ONEWEB_0654" % plane 18 idx 50
    "ONEWEB_0187" % plane 18 idx 51
    "ONEWEB_0220" % plane 18 idx 52
    "ONEWEB_0219" % plane 18 idx 53
    "ONEWEB_0201" % plane 18 idx 54
    "ONEWEB_0185" % plane 18 idx 55
    "ONEWEB_0513" % plane 19 idx 1
    "ONEWEB_0495" % plane 19 idx 2
    "ONEWEB_0505" % plane 19 idx 3
    "ONEWEB_0639" % plane 19 idx 4
    "ONEWEB_0645" % plane 19 idx 5
    "ONEWEB_0512" % plane 19 idx 6
    "ONEWEB_0501" % plane 19 idx 7
    "ONEWEB_0649" % plane 19 idx 8
    "ONEWEB_0504" % plane 19 idx 9
    "ONEWEB_0502" % plane 19 idx 10
    "ONEWEB_0508" % plane 19 idx 11
    "ONEWEB_0525" % plane 19 idx 12
    "ONEWEB_0720" % plane 19 idx 13
    "ONEWEB_0520" % plane 19 idx 14
    "ONEWEB_0642" % plane 19 idx 15
    "ONEWEB_0499" % plane 19 idx 16
    "ONEWEB_0507" % plane 19 idx 17
    "ONEWEB_0506" % plane 19 idx 18
    "ONEWEB_0671" % plane 19 idx 19
    "ONEWEB_0522" % plane 19 idx 20
    "ONEWEB_0529" % plane 19 idx 21
    "ONEWEB_0376" % plane 19 idx 22
    "ONEWEB_0518" % plane 19 idx 23
    "ONEWEB_0490" % plane 19 idx 24
    "ONEWEB_0644" % plane 19 idx 25
    "ONEWEB_0380" % plane 19 idx 26
    "ONEWEB_0511" % plane 19 idx 27
    "ONEWEB_0658" % plane 19 idx 28
    "ONEWEB_0641" % plane 19 idx 29
    "ONEWEB_0509" % plane 19 idx 30
    "ONEWEB_0369" % plane 19 idx 31
    "ONEWEB_0646" % plane 19 idx 32
    "ONEWEB_0365" % plane 19 idx 33
    "ONEWEB_0519" % plane 19 idx 34
    "ONEWEB_0650" % plane 19 idx 35
    "ONEWEB_0497" % plane 19 idx 36
    "ONEWEB_0516" % plane 19 idx 37
    "ONEWEB_0517" % plane 19 idx 38
    "ONEWEB_0673" % plane 19 idx 39
    "ONEWEB_0503" % plane 19 idx 40
    "ONEWEB_0526" % plane 19 idx 41
    "ONEWEB_0388" % plane 19 idx 42
    "ONEWEB_0492" % plane 19 idx 43
    "ONEWEB_0371" % plane 19 idx 44
    "ONEWEB_0362" % plane 19 idx 45
    "ONEWEB_0521" % plane 19 idx 46
    "ONEWEB_0500" % plane 19 idx 47
    "ONEWEB_0514" % plane 19 idx 48
    "ONEWEB_0675" % plane 19 idx 49
    "ONEWEB_0535" % plane 19 idx 50
    "ONEWEB_0657" % plane 19 idx 51
];

OneWeb_geo = [
    "GSAT_11"
    "GSAT_19"
    "GSAT_29"
    "INMARSAT_5_F1"
    "INMARSAT_5_F2"
    "INMARSAT_5_F3"
    "INMARSAT_5_F4"
    "INTELSAT_32E"
    "INTELSAT_35E"
    "KAZSAT_2"
    "KAZSAT_3"
    "KOREASAT_5"
    "TDRS_8"
    "TDRS_11"
    "TDRS_12"
    "TDRS_13"
    "WGS_F1"
    "WGS_F2"
    "WGS_F3"
    "WGS_F4"
    "WGS_F5"
    "WGS_F6"
    "WGS_F7"
    "WGS_F8"
    "WGS_F9"
    "WGS_10"
];

OneWeb_OMNet_geo = [
    "geo_1",   % GSAT_11
    "geo_2",   % GSAT_19
    "geo_3",   % GSAT_29
    "geo_4_1",   % INMARSAT_5 F1
    "geo_4_2",   % INMARSAT_5 F2
    "geo_4_3",   % INMARSAT_5 F3
    "geo_4_4",   % INMARSAT_5 F4
    "geo_5",   % INTELSAT_32E
    "geo_6",   % INTELSAT_35E
    "geo_7",   % KAZSAT_2
    "geo_8",   % KAZSAT_3
    "geo_9",   % KOREASAT_5
    "geo_12",   % TDRS_11
    "geo_13",   % TDRS_12
    "geo_14",   % TDRS_13
    "geo_15",   % TDRS_8
    "geo_16_1",   % WGS_F1
    "geo_16_2",   % WGS_F2
    "geo_16_3",   % WGS_F3
    "geo_16_4",   % WGS_F4
    "geo_16_5",   % WGS_F5
    "geo_16_6",   % WGS_F6
    "geo_16_7",   % WGS_F7
    "geo_16_8",   % WGS_F8
    "geo_16_9",   % WGS_F9
    "geo_17"    % WGS_10
];

OneWeb_OMNet_geo_part = [
    "geo_1",   % GSAT_11
    "geo_2",   % GSAT_19
    "geo_3",   % GSAT_29
    "geo_4_1",   % INMARSAT_5 F1
    "geo_4_4",   % INMARSAT_5 F4
    "geo_7",   % KAZSAT_2
    "geo_8",   % KAZSAT_3
    "geo_12",   % TDRS_11
    "geo_16_2",   % WGS_F2
    "geo_16_3",   % WGS_F3
    "geo_16_4",   % WGS_F4
    "geo_17"    % WGS_10
];


geoLongitudes = [
    74.302
    48.279
    55.453
    63.014
    -54.654
    179.909
    56.866
    -42.781
    -34.151
    86.902
    58.869
    113.446
    57.871
    -174.77
    -40.615
    -11.060
    -42.151
    57.870
    78.604
    88.792
    -52.145
    -134.812
    175.358
    150.161
    -11.628
    60.680
 ];


end