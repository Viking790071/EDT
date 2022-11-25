
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	Value = Common.CommonSettingsStorageLoad(
		"TemplateOpeningSettings", 
		"PromptForTemplateOpeningMode");
	
	If Value = Undefined Then
		DontAskAgain = False;
	Else
		DontAskAgain = NOT Value;
	EndIf;
	
	Value = Common.CommonSettingsStorageLoad(
		"TemplateOpeningSettings", 
		"TemplateOpeningModeView");
	
	If Value = Undefined Then
		HowToOpen = 0;
	Else
		If Value Then
			HowToOpen = 0;
		Else
			HowToOpen = 1;
		EndIf;
	EndIf;
	
	If CommonClientServer.IsMobileClient() Then // This is a temporary solution for mobile client. It will be removed from next versions.
		
		CommandBarLocation = FormCommandBarLabelLocation.Auto;
		
		CommonClientServer.SetFormItemProperty(Items, "MobileClientGroup", "Visible", True);
		CommonClientServer.SetFormItemProperty(Items, "Group", "Visible", False);
		CommonClientServer.SetFormItemProperty(Items, "Cancel", "Visible", False);
		
	EndIf;
	
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	
	PromptForTemplateOpeningMode = NOT DontAskAgain;
	TemplateOpeningModeView = ?(HowToOpen = 0, True, False);
	
	SaveTemplateOpeningModeSettings(PromptForTemplateOpeningMode, TemplateOpeningModeView);
	
	NotifyChoice(New Structure("DontAskAgain, OpeningModeView",
							DontAskAgain,
							TemplateOpeningModeView) );
	
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Procedure SaveTemplateOpeningModeSettings(PromptForTemplateOpeningMode, TemplateOpeningModeView)
	
	Common.CommonSettingsStorageSave(
		"TemplateOpeningSettings", 
		"PromptForTemplateOpeningMode", 
		PromptForTemplateOpeningMode);
	
	Common.CommonSettingsStorageSave(
		"TemplateOpeningSettings", 
		"TemplateOpeningModeView", 
		TemplateOpeningModeView);
	
EndProcedure

#EndRegion
