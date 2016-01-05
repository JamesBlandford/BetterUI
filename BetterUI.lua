local wm = GetWindowManager()
local em = GetEventManager()
local _

if BUI == nil then BUI = {} end

BUI.name = "BetterUI"
BUI.version = "0.05"

local LAM = LibStub:GetLibrary("LibAddonMenu-2.0")

BUI.settings = {}
BUI.inventory = {}

BUI.defaults = {
	showUnitPrice=true,
	showMMPrice=true
}

function BUI.SetupOptionsMenu()

	local panelData = {
		type = "panel",
		name = BUI.name,
		displayName = "Better gamepad interface Settings",
		author = "prasoc",
		version = BUI.version,
		slashCommand = "/bui",	--(optional) will register a keybind to open to this panel
		registerForRefresh = true,	--boolean (optional) (will refresh all options controls when a setting is changed and when the panel is shown)
		registerForDefaults = false,	--boolean (optional) (will set all options controls back to default values)
	}

	local optionsTable = {
		[1] = {
			type = "header",
			name = "General Settings",
			width = "full",	--or "half" (optional)
		},
		[2] = {
			type = "description",
			--title = "My Title",	--(optional)
			title = nil,	--(optional)
			text = "Toggle main addon functions here",
			width = "full",	--or "half" (optional)
		},
		[3] = {
			type = "checkbox",
			name = "Unit Price in Guild Store",
			tooltip = "Displays a price per unit in guild store listings",
			getFunc = function() return BUI.settings.showUnitPrice end,
			setFunc = function(value) BUI.settings.showUnitPrice = value end,
			width = "full",	--or "half" (optional)
		},
		[4] = {
			type = "checkbox",
			name = "MasterMerchant Price in Guild Store",
			tooltip = "Displays the MM percentage in guild store listings",
			getFunc = function() return BUI.settings.showMMPrice end,
			setFunc = function(value) BUI.settings.showMMPrice = value end,
			width = "full",	--or "half" (optional)
		},
	}
	LAM:RegisterAddonPanel("NewUI", panelData)
	LAM:RegisterOptionControls("NewUI", optionsTable)
end

local function PostHook(control, method, postHookFunction, overwriteOriginal)
	if control == nil then return end

	local originalMethod = control[method]
	control[method] = function(self, ...)
		if(overwriteOriginal == false) then originalMethod(self, ...) end
		postHookFunction(self, ...)
	end

	d(zo_strformat("[NUI] Successfully hooked into :<<2>>(...)",control,method))
end


local function SetupGStoreListing(control, data, selected, selectedDuringRebuild, enabled, activated)
    ZO_SharedGamepadEntry_OnSetup(control, data, selected, selectedDuringRebuild, enabled, activated)
    local notEnoughMoney = data.purchasePrice > GetCarriedCurrencyAmount(CURT_MONEY)
    ZO_CurrencyControl_SetSimpleCurrency(control.price, CURT_MONEY, data.purchasePrice, ZO_GAMEPAD_CURRENCY_OPTIONS, CURRENCY_SHOW_ALL, notEnoughMoney)
    local sellerControl = control:GetNamedChild("SellerName")
    local unitPriceControl = control:GetNamedChild("UnitPrice")
    local buyingAdviceControl = control:GetNamedChild("BuyingAdvice")
    local sellerName, dealString, margin

    if(BUI.MMIntegration) then
    	sellerName, dealString, margin = zo_strsplit(';', data.sellerName)
    else
    	sellerName = data.sellerName
   	end

    if(BUI.settings.showMMPrice) then
	    dealValue = tonumber(dealString)

	    local r, g, b = GetInterfaceColor(INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS, dealValue)
        if dealValue == 0 then r = 0.98; g = 0.01; b = 0.01; end

        buyingAdviceControl:SetHidden(false)
        buyingAdviceControl:SetColor(r, g, b, 1)
        buyingAdviceControl:SetText(margin..'%')

   		sellerControl:SetText(ZO_FormatUserFacingDisplayName(sellerName))
	else
		buyingAdviceControl:SetHidden(true)
   		sellerControl:SetText(ZO_FormatUserFacingDisplayName(sellerName))
	end

    if(BUI.settings.showUnitPrice) then
	   	if(data.stackCount ~= 1) then 
	    	unitPriceControl:SetHidden(false)
	    	unitPriceControl:SetText(zo_strformat("@<<1>> |t16:16:EsoUI/Art/currency/currency_gold.dds|t",data.purchasePrice/data.stackCount))
	    else 
	    	unitPriceControl:SetHidden(true)
	    end
    else
    	unitPriceControl:SetHidden(true)
    end

    local timeRemainingControl = control:GetNamedChild("TimeLeft")
    if data.isGuildSpecificItem then
        timeRemainingControl:SetHidden(true)
    else
        timeRemainingControl:SetHidden(false)
        timeRemainingControl:SetText(zo_strformat(SI_TRADING_HOUSE_BROWSE_ITEM_REMAINING_TIME, ZO_FormatTime(data.timeRemaining, TIME_FORMAT_STYLE_SHOW_LARGEST_UNIT_DESCRIPTIVE, TIME_FORMAT_PRECISION_SECONDS, TIME_FORMAT_DIRECTION_DESCENDING)))
    end
end

function BUI.SetupMMIntegration() 
  	if MasterMerchant.LibAddonInit == nil then 
  		BUI.MMIntegration = false
  		return 
  	end
  	MasterMerchant.initBuyingAdvice = function(self, ...) end
  	MasterMerchant.initSellingAdvice = function(self, ...) end
  	MasterMerchant.AddBuyingAdvice = function(rowControl, result) end
  	MasterMerchant.AddSellingAdvice = function(rowControl, result)	end
  	BUI.MMIntegration = true
end

function BUI.SetupCustomGuildResults()

	-- overwrite old results scrolllist data type and replace:
	GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS:GetList().dataTypes["ZO_TradingHouse_ItemListRow_Gamepad"]=nil
	GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS:GetList().dataTypes["NewUI_ItemListRow_Gamepad"] = {
            pool = ZO_ControlPool:New("NewUI_ItemListRow_Gamepad", GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS:GetList().scrollControl, "NewUI_ItemListRow_Gamepad"),
            setupFunction = SetupGStoreListing,
            parametricFunction = ZO_GamepadMenuEntryTemplateParametricListFunction,
            equalityFunction = function(l,r) return l == r end,
            hasHeader = false,
        }

    -- overwrite old results add entry function to use the new scrolllist datatype:
	PostHook(GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS, "AddEntryToList", function(self, itemData) 
		self.footer.pageNumberLabel:SetHidden(false)
        self.footer.pageNumberLabel:SetText(zo_strformat("<<1>>", self.currentPage + 1)) -- Pages start at 0, offset by 1 for expected display number
        if(itemData) then
	        local entry = ZO_GamepadEntryData:New(itemData.name, itemData.iconFile)
	        entry:InitializeTradingHouseVisualData(itemData)
	        self:GetList():AddEntry("NewUI_ItemListRow_Gamepad", 
	                                entry, 
	                                SCROLL_LIST_HEADER_OFFSET_VALUE, 
	                                SCROLL_LIST_HEADER_OFFSET_VALUE, 
	                                SCROLL_LIST_SELECTED_OFFSET_VALUE, 
	                                SCROLL_LIST_SELECTED_OFFSET_VALUE)
    	end
	end, true)
end


function BUI.Initialize(event, addon)
    -- filter for just NUI addon event
	if addon ~= BUI.name then return end

	-- load our saved variables
	BUI.settings = ZO_SavedVars:New("BetterUISavedVars", 1, nil, BUI.defaults)
	em:UnregisterForEvent("BetterUIInitialize", EVENT_ADD_ON_LOADED)

	BUI.SetupCustomGuildResults()
	BUI.SetupMMIntegration()
	BUI.SetupOptionsMenu()
end

-- register our event handler function to be called to do initialization
em:RegisterForEvent(BUI.name, EVENT_ADD_ON_LOADED, function(...) BUI.Initialize(...) end)