local U={}
function U.copy(t) if type(t)~="table" then return t end local o={}; for k,v in pairs(t) do o[k]=U.copy(v) end; return o end
function U.shuffle(t,rng) local o=table.clone(t); for i=#o,2,-1 do local j=rng:NextInteger(1,i); o[i],o[j]=o[j],o[i] end; return o end
function U.finite(n) return type(n)=="number" and n==n and math.abs(n)<1e7 end
function U.vector(v) return typeof(v)=="Vector3" and U.finite(v.X) and U.finite(v.Y) and U.finite(v.Z) end
function U.root(m) return m and m:FindFirstChild("HumanoidRootPart") end
function U.humanoid(m) return m and m:FindFirstChildOfClass("Humanoid") end
function U.contains(t,v) return table.find(t,v)~=nil end
function U.color(a) return Color3.fromRGB(a[1],a[2],a[3]) end
return U
