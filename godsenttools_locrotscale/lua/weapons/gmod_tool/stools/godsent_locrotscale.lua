TOOL.Category = "Construction"
TOOL.Name = "#tool.godsent_locrotscale.name"
TOOL.ClientConVar["propkey"] = KEY_N
TOOL.ClientConVar["proptoggle"] = 0
TOOL.ClientConVar["rotationpyr"] = 1
TOOL.Information = { }
local CheckDrag

do
	local utilIntersectRayWithPlane, mathabs = util.IntersectRayWithPlane, math.abs

	function CheckDrag(center, planeNormal, rayOrigin, rayDirection, size, tolerance)
		local hitpos = utilIntersectRayWithPlane(rayOrigin, rayDirection, center, planeNormal)
		if not hitpos then return end
		local dist = hitpos - center
		local distdelta = mathabs(size - dist:LengthSqr())
		if distdelta > tolerance then return end

		if SERVER then
			debugoverlay.Cross(hitpos, 1, 10)
		end

		dist:Normalize()

		return dist, hitpos, distdelta
	end
end

TOOL.CheckDrag = CheckDrag
local GetPlaneNormal

do
	local utilIntersectRayWithPlane = util.IntersectRayWithPlane

	function GetPlaneNormal(center, planeNormal, rayOrigin, rayDirection)
		local hitpos = utilIntersectRayWithPlane(rayOrigin, rayDirection, center, planeNormal)
		if not hitpos then return end
		local dist = hitpos - center
		dist:Normalize()

		return dist, hitpos
	end
end

TOOL.GetPlaneNormal = GetPlaneNormal
local ceiloor

do
	local floor, ceil = math.floor, math.ceil

	function ceiloor(n)
		if n < 0 then return ceil(n) end

		return floor(n)
	end
end

TOOL.ceiloor = ceiloor

do
	function TOOL:LeftClick(tr)
		local op = self:GetOperation()

		if op == 0 and tr.Entity then
			return self:SelectTry(tr.Entity, tr)
		elseif op == 2 then
			self:RotateTry(tr)
		end

		return false
	end
end

do
	local IsValid = IsValid

	function TOOL:RightClick(tr)
		if IsValid(self.TargetEntity) then
			local op = self:GetOperation()

			if not self.Pressed then
				self:SetOperation((op + 1) % 3)

				return
			end

			self:CancelAction(op)
		else
			self:SetOperation(0)
		end

		return false
	end
end

function TOOL:Reload(t)
	local op = self:GetOperation()

	if op == 0 then
		if CLIENT then
			self:SelectionMenu(t.Entity, t)
		end

		if SERVER and game.SinglePlayer() then
			net.Start("GodSentToolsLocRotScale")
			net.WriteEntity(self.SWEP)
			net.WriteUInt(5, 3)
			net.Send(self:GetOwner())
		end
	end
end

do
	local SERVER, netWriteEntity, netSend, netWriteUInt, netStart, gameSinglePlayer = SERVER, net.WriteEntity, net.Send, net.WriteUInt, net.Start, game.SinglePlayer

	-- local flags = {
	-- 	["BONE_PHYSICALLY_SIMULATED"] = BONE_PHYSICALLY_SIMULATED,
	-- 	["BONE_PHYSICS_PROCEDURAL"] = BONE_PHYSICS_PROCEDURAL,
	-- 	["BONE_ALWAYS_PROCEDURAL"] = BONE_ALWAYS_PROCEDURAL,
	-- 	["BONE_SCREEN_ALIGN_SPHERE"] = BONE_SCREEN_ALIGN_SPHERE,
	-- 	["BONE_SCREEN_ALIGN_CYLINDER"] = BONE_SCREEN_ALIGN_CYLINDER,
	-- 	["BONE_CALCULATE_MASK"] = BONE_CALCULATE_MASK,
	-- 	["BONE_USED_BY_HITBOX"] = BONE_USED_BY_HITBOX,
	-- 	["BONE_USED_BY_ATTACHMENT"] = BONE_USED_BY_ATTACHMENT,
	-- 	["BONE_USED_BY_VERTEX_MASK"] = BONE_USED_BY_VERTEX_MASK,
	-- 	["BONE_USED_BY_BONE_MERGE"] = BONE_USED_BY_BONE_MERGE,
	-- 	["BONE_USED_MASK"] = BONE_USED_MASK
	-- }
	function TOOL:SetTargetEntity(ent, bonen)
		self.TargetEntity = ent
		self.TargetBone = bonen
		self.TargetBoneMode = false
		self.BonePos, self.BoneAng = Vector(), Angle()

		if SERVER then
			local phys = ent:TranslateBoneToPhysBone(bonen)

			if ent:TranslatePhysBoneToBone(phys) ~= bonen then
				phys = -2
			end

			if not phys or phys == -1 then
				error("[1] Report Spar")
			end

			if ent:GetPhysicsObjectCount() > phys then
				local physobj = ent:GetPhysicsObjectNum(phys)

				if physobj then
					self.TargetPhysBone = phys
					self.TargetPhys = physobj
					self.RefreshCache = true
					self.TargetBoneMode = true
				end
			end
		end

		if SERVER then
			local wep = self.SWEP
			local p = wep:GetParent()
			wep:FollowBone(ent, 0)
			wep:SetParent(p)
		end

		if SERVER and gameSinglePlayer() then
			netStart("GodSentToolsLocRotScale")
			netWriteEntity(self.SWEP)
			netWriteUInt(0, 3)
			netWriteEntity(ent)
			netWriteUInt(bonen, 8)
			net.WriteBool(self.TargetBoneMode)
			netSend(self:GetOwner())
		end
	end
end

do
	local SERVER, netWriteEntity, netSend, netWriteUInt, netStart, gameSinglePlayer = SERVER, net.WriteEntity, net.Send, net.netWriteUInt, net.Start, game.SinglePlayer

	function TOOL:CancelAction(op)
		self.Pressed = false

		if op == 2 then
			if SERVER then
				self.TargetEntity:ManipulateBoneAngles(self.TargetBone, self.RotationOriginal)
			end

			self:RotateEnd()
			-- self:GetOwner():SetEyeAngles((self.RotationStart - self:GetOwner():EyePos()):Angle())
		end

		if SERVER and gameSinglePlayer() then
			netStart("GodSentToolsLocRotScale")
			netWriteEntity(self.SWEP)
			netWriteUInt(2, 3)
			netSend(self:GetOwner())
		end
	end
end

do
	local SERVER, netWriteEntity, netSend, netWriteDouble, netWriteNormal, netWriteAngle, netWriteUInt, netStart, gameSinglePlayer, mathfmod = SERVER, net.WriteEntity, net.Send, net.WriteDouble, net.WriteNormal, net.WriteAngle, net.WriteUInt, net.Start, game.SinglePlayer, math.fmod

	function TOOL:RotateStart(dir, start, ma, OFA, deg, dircolor)
		self.Pressed = true
		self.RotationDir = dir
		self.RotationStart = start

		if SERVER then
			if self.TargetBoneMode then
				self.RotationOriginal = self.TargetPhys:GetAngles()
				self:CachePhys(self.TargetEntity)
			else
				self.RotationOriginal = self.TargetEntity:GetManipulateBoneAngles(self.TargetBone)
			end

		end

		self.RotationDirAng = ma
		if not ma then error("[2] Report Spar") end
		self.RotationStartAng = OFA
		self.RotationStartDeg = deg
		self.RotationStartSnapOffset = mathfmod(deg, 5)
		self.RotationDirColor = dircolor

		if SERVER and gameSinglePlayer() then
			netStart("GodSentToolsLocRotScale")
			netWriteEntity(self.SWEP)
			netWriteUInt(1, 3)
			netWriteNormal(dir)
			netWriteNormal(start)
			netWriteAngle(ma)
			netWriteAngle(OFA)
			netWriteDouble(deg)
			netWriteUInt(dircolor, 2)
			netSend(self:GetOwner())
		end
	end
end

function TOOL:RotateEnd()
	self.Pressed = false
	self:GetOwner():DrawViewModel(true)
	self.RotationDir, self.RotationStart, self.RotationOriginal, self.RotationDirAng, self.RotationStartAng, self.RotationStartDeg, self.RotationStartSnapOffset, self.RotationDirColor = nil
end

do
	local HovEntBones = { }

	function TOOL:SelectTry(E, t)
		if not E or not E:IsValid() then return end
		local k = E:GetBoneCount()
		local hit = t.HitPos
		local closest, closestbone = math.huge

		do
			local HovEntBones = HovEntBones
			local epos = E:GetPos()

			for i = 0, k - 1 do
				local v = E:GetBonePosition(i)

				if not v or v == epos then
					v = E:GetBoneMatrix(i):GetTranslation()
				end

				local dist = hit:DistToSqr(v)
				HovEntBones[i] = v

				if not E:BoneHasFlag(i, BONE_ALWAYS_PROCEDURAL) and closest > dist then
					closest = dist
					closestbone = i
				end
			end
		end

		if closestbone then
			self:SetTargetEntity(E, closestbone)

			return true
		end

		return false
	end
end

do
	local vector_origin, WorldToLocal, Vector1, mathhuge, angle_zero, LocalToWorld = vector_origin, WorldToLocal, Vector(1), math.huge, angle_zero, LocalToWorld
	local ToDegVector, DegToAngle = Vector(), Angle()

	function TOOL:RotateTry(t)
		local E = self.TargetEntity

		if E and E:IsValid() then
			local A, P = self.BoneAng, self.BonePos
			local closest, closestpos, closesthit, closestdir, dircolor = mathhuge

			do
				local EyePos = t.StartPos
				local dist = P - EyePos
				local D = dist:Angle():Forward()
				dist = dist:LengthSqr() * (0.3 ^ 2)
				local tolerance = dist * 0.1
				local TraceNormal = t.Normal
				local CheckDrag = CheckDrag

				do
					local dir = A:Forward()
					local pos, hit, close = CheckDrag(P, dir, EyePos, TraceNormal, dist, tolerance)

					if pos and closest > close then
						closest, closestpos, closesthit, closestdir, dircolor = close, pos, hit, dir, 0
					end
				end

				do
					local dir = A:Right()
					local pos, hit, close = CheckDrag(P, dir, EyePos, TraceNormal, dist, tolerance)

					if pos and closest > close then
						closest, closestpos, closesthit, closestdir, dircolor = close, pos, hit, dir, 1
					end
				end

				do
					local dir = A:Up()
					local pos, hit, close = CheckDrag(P, dir, EyePos, TraceNormal, dist, tolerance)

					if pos and closest > close then
						closest, closestpos, closesthit, closestdir, dircolor = close, pos, hit, dir, 2
					end
				end

				do
					local dir = D
					dist = dist * 1.5
					local pos, hit, close = CheckDrag(P, dir, EyePos, TraceNormal, dist, dist * 0.1)

					if pos and closest > close then
						closest, closestpos, closesthit, closestdir, dircolor = close, pos, hit, dir, 3
					end
				end
			end

			if closestpos then
				local ma = closestdir:AngleEx(Vector1)
				local temp
				local Y

				do
					local ToDegVector = ToDegVector
					temp = WorldToLocal(closesthit, angle_zero, P, ma)
					ToDegVector:SetUnpacked(temp[2], temp[3], 0)
					Y = ToDegVector:Angle()[2]
				end

				local grabang

				do
					local DegToAngle = DegToAngle
					DegToAngle:SetUnpacked(0, 0, Y)
					temp, grabang = LocalToWorld(vector_origin, DegToAngle, P, ma)
				end

				-- self.RotationStartGrabAng = grabang
				-- self.RotationStartGrabAngSnapped = Angle(math.fmod(grabang[1],5), math.fmod(grabang[2],5), math.fmod(grabang[3],5))
				do
					local _a
					temp, _a = WorldToLocal(P, A, P, grabang)
					self:RotateStart(closestdir, closestpos, ma, _a, Y, dircolor)
				end
			end
		end
	end
end

if CLIENT then
	include("godsent_locrotscale/cl_init.lua")
else
	include("godsent_locrotscale/init.lua")
	AddCSLuaFile("godsent_locrotscale/cl_init.lua")
end