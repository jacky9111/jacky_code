function ang = pt_angle_deg(a, b)
ang = acosd( max(-1, min(1, dot(a, b)/(norm(a)*norm(b))) ) );
end
