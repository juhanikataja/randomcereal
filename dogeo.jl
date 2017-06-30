using netgengen

#defaults
Rref = 1.0
min_radius=1
max_radius=2
padding = max_radius*2

a = 8
b = 17
p = [0.0,0.0,0.0]
q = [1.0,0.0,0.0]

num_coil = 10
num_tries = 10000


type Coil
  a::Float64
  b::Float64
  radius::Float64
  center::Array{Float64,1}
  normal::Array{Float64,1}
  csg_geom::torus
  Coil(name::String,p,q,R::Float64;modifiers...) = 
  (x = new();
   x.a = a;
   x.b = b;
   x.center=p;
   x.normal=q;
   x.radius = R;
   x.csg_geom = torus(name, x.center, x.normal, x.b*x.radius/(x.a+x.b), x.a*x.radius/(x.a+x.b);modifiers...);
   return x)
end 

function coil_intersects(coil_a::Coil, coil_b::Coil, sep=0.0)
  coil_distance(coil_a, coil_b) = norm(coil_a.center-coil_b.center)
  if coil_distance(coil_a, coil_b) > coil_a.radius + coil_b.radius + sep
    return false
  end
  return true
end

function cram_coil!(coils::Array{Coil,1}, coil)
  for x in coils
    if coil_intersects(x, coil)
      return false
    end 
  end
  push!(coils, coil)
  return true
end

coil_array = Array{Coil,1}()
n = 1
m = 1
sizes=linspace(min_radius,max_radius,100)

# make the coils
while n <= num_coil && m <= num_tries
  normal = randn(3)
  normal = normal/norm(normal)
  origin = randn(3)*Rref
  radius = rand(sizes)
  if cram_coil!(coil_array, Coil("coil_$(n)", origin, normal, radius))
    n = n + 1
  else
    m = m + 1
  end
end

# find enclosing box + padding
P = coil_array[1].center-coil_array[1].radius
Q = coil_array[1].center+coil_array[1].radius

for c in coil_array
  for k = 1:3
    if c.center[k]-c.radius<=P[k]+padding
      P[k] = c.center[k]-c.radius-padding
    end
  end
  for k = 1:3
    if c.center[k]+c.radius>=Q[k]-padding
      Q[k] = c.center[k]+c.radius+padding
    end
  end
end

not_tori=Array{CSGObject,1}()
for x in coil_array
  push!(not_tori, not(x.csg_geom))
end
airbrick=brick("airbrick",P,Q,bc=1,transparent=true)
push!(not_tori, airbrick)
air = intersection("air",not_tori)

geo_io=open("random_tori.geo","w")
print(geo_io, "algebraic3d\n")
tlo(air,geo_io)
for x in coil_array
  tlo(x.csg_geom,geo_io)
end
close(geo_io)

sifinfo = open("coil_data.sif","w")
for n = 1:length(coil_array)
  c = coil_array[n]
  co = c.center
  cn = c.normal
  print(sifinfo,"!Coil $(n)------------------------\n")
  print(sifinfo,"coil normal(3) = real $(cn[1]) $(cn[2]) $(cn[3])\n")
  print(sifinfo,"coil origin(3) = real $(co[1]) $(co[2]) $(co[3])\n\n")
end
close(sifinfo)
