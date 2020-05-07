module ExampleModule

"""
    heart()

Credit to https://discourse.julialang.org/t/love-in-245-characters-code-golf/20771
"""
function heart()
    0:2e-3:2π    .|>d->(P=
    fill(5<<11,64 ,25);z=8cis(
   d)sin(.46d);P[ 64,:].=10;for
   r=0:98,c=0 :5^3 x,y=@.mod(2-
   $reim((.016c-r/49im-1-im)z),
    4)-2;4-x^2>√2(y+.5-√√x^2)^
     2&&(P[c÷2+1,r÷4+1]|=Int(
       ")*,h08H¨"[4&4c+1+r&
         3])-40)end;print(
          "\e[H\e[1;31m",
            join(Char.(
               P)))
                );
    return nothing
end

end #module