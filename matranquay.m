function R = matranquay(roll, pitch, yaw)
    Rz = [cosd(yaw), -sind(yaw), 0;
          sind(yaw),  cosd(yaw), 0;
               0   ,      0   , 1];
               
    Ry = [ cosd(pitch), 0, sind(pitch);
           0 ,       1,     0   ;
          -sind(pitch), 0, cosd(pitch)];
          
    Rx = [1,   0,           0     ;
          0, cosd(roll), -sind(roll);
          0, sind(roll),  cosd(roll)];
          
    R = Rz * Ry * Rx;
end