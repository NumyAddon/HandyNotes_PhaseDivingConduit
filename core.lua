local addonName = ...;
--- @class PhaseDivingConduit_NS
local ns = select(2, ...);
local PDC = LibStub('AceAddon-3.0'):NewAddon(addonName);

local HandyNotes = LibStub('AceAddon-3.0'):GetAddon('HandyNotes', true);
if not HandyNotes then return; end

local HBD = LibStub('HereBeDragons-2.0');

--@debug@
_G.HN_PhaseDivingConduit = PDC;
--@end-debug@

local mapID = 2371; -- K'aresh
local cityMapID = 2472; -- Tazavesh
local atlas = 'flightmaster_ancientwaygate-taxinode_neutral';
local atlasInfo = C_Texture.GetAtlasInfo(atlas);
local iconDefault = {
    icon = atlasInfo.file,
    tCoordLeft = atlasInfo.leftTexCoord,
    tCoordRight = atlasInfo.rightTexCoord,
    tCoordTop = atlasInfo.topTexCoord,
    tCoordBottom = atlasInfo.bottomTexCoord,
};

local locations = ns.locations;

--- @class PhaseDivingConduit_Node
--- @field x number
--- @field y number
--- @field name string
--- @field taxiNodeID number

--- @type table<number, PhaseDivingConduit_Node[]> # [uiMapID] = list of locations
PDC.nodes = {
    [mapID] = {},
    [cityMapID] = {},
};

function PDC:OnInitialize()
    for _, pin in ipairs(locations) do
        local x, y = HBD:GetZoneCoordinatesFromWorld(pin.pos1, pin.pos0, mapID);
        if x and y then
            local coord = HandyNotes:getCoord(x, y);
            --- @type PhaseDivingConduit_Node
            self.nodes[mapID][coord] = {
                name = pin.name,
                taxiNodeID = pin.taxiNodeID,
                x = x,
                y = y,
            };
        end
        x, y = HBD:GetZoneCoordinatesFromWorld(pin.pos1, pin.pos0, cityMapID);
        if x and y then
            local coord = HandyNotes:getCoord(x, y);
            --- @type PhaseDivingConduit_Node
            self.nodes[cityMapID][coord] = {
                name = pin.name,
                taxiNodeID = pin.taxiNodeID,
                x = x,
                y = y,
            };
        end
    end

    local defaults = {
        profile = {
            iconScale = 1.0,
            iconAlpha = 1.0,
        },
    };
    self.db = LibStub('AceDB-3.0'):New('HandyNotes_PhaseDivingConduitDB', defaults, true).profile;

    if (C_AddOns.IsAddOnLoaded('TomTom')) then
        self.isTomTomLoaded = true;
    end
    local increment = CreateCounter(1);
    local options = {
        type = 'group',
        name = 'Phase Diving Conduit',
        desc = 'Locations of Phase Diving Conduits on K\'aresh',
        get = function(info) return self.db[info[#info]]; end,
        set = function(info, v) self.db[info[#info]] = v; self:Refresh(); end,
        args = {
            desc = {
                name = 'These settings control the look and feel of the icon.',
                type = 'description',
                order = increment(),
            },
            iconScale = {
                type = 'range',
                name = 'Icon Scale',
                desc = 'The scale of the icons',
                min = 0.25, max = 3, step = 0.01,
                order = increment(),
            },
            iconAlpha = {
                type = 'range',
                name = 'Icon Alpha',
                desc = 'The alpha transparency of the icons',
                min = 0, max = 1, step = 0.01,
                order = increment(),
            },
        },
    };
    HandyNotes:RegisterPluginDB(addonName, self, options);
end

local superTrackedTaxiNodeID;
local function iter(t, previousIndex)
    if not t then return nil; end
    local index, value = next(t, previousIndex);
    while index and value do
        --- @type PhaseDivingConduit_Node
        local node = value;
        local scaleModifier = superTrackedTaxiNodeID == node.taxiNodeID and 1.6 or 1.2;

        return index, nil, iconDefault, PDC.db.iconScale * scaleModifier, PDC.db.iconAlpha * 2;
    end
end
function PDC:GetNodes2(uiMapId, isMinimapUpdate)
    if not self.nodes[uiMapId] or isMinimapUpdate then return function() end end

    superTrackedTaxiNodeID = nil;
    local type, id = C_SuperTrack.GetSuperTrackedMapPin();
    if type == Enum.SuperTrackingMapPinType.TaxiNode then
        superTrackedTaxiNodeID = id;
    end
    return iter, self.nodes[uiMapId], nil
end

function PDC.OnClick(mapPin, button, down, mapFile, coord)
    if not down then return; end
    local node = PDC.nodes[mapFile][coord];
    if not node then return; end
    if IsAltKeyDown() and PDC.isTomTomLoaded then
        TomTom:AddWaypoint(mapFile, node.x, node.y, {
            title = node.name,
            from = addonName,
            persistent = nil,
            minimap = true,
            world = true,
        });
    elseif node.taxiNodeID then
        local type, id = C_SuperTrack.GetSuperTrackedMapPin();
        if type == Enum.SuperTrackingMapPinType.TaxiNode and id == node.taxiNodeID then
            C_SuperTrack.ClearSuperTrackedMapPin();
        else
            C_SuperTrack.SetSuperTrackedMapPin(Enum.SuperTrackingMapPinType.TaxiNode, node.taxiNodeID);
        end
        PDC:Refresh();
    end
end

function PDC.OnEnter(mapPin, mapFile, coord)
    local node = PDC.nodes[mapFile][coord];
    if not node then return; end

    if mapPin:GetCenter() > UIParent:GetCenter() then
        GameTooltip:SetOwner(mapPin, 'ANCHOR_LEFT');
    else
        GameTooltip:SetOwner(mapPin, 'ANCHOR_RIGHT');
    end

    local text = node.name;
    GameTooltip:SetText('Phase Conduit');
    GameTooltip:AddLine(text);

    GameTooltip_AddInstructionLine(GameTooltip, 'Click to toggle SuperTrack');
    if PDC.isTomTomLoaded then
        GameTooltip_AddInstructionLine(GameTooltip, 'Alt-click to set TomTom waypoint');
    end
    GameTooltip:Show();
end

function PDC:OnLeave()
    GameTooltip:Hide()
end

function PDC:Refresh()
    HandyNotes:SendMessage('HandyNotes_NotifyUpdate', addonName);
end
