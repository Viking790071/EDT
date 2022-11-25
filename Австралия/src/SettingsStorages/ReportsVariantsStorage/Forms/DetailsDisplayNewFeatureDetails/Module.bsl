#Region EventHandlers

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Exit Then
		Return;
	EndIf;
	
	CommonSettings = BeforeCloseAtServer(DisableDetails);
	Notify(
		ReportsOptionsClientServer.EventNameChangingCommonSettings(),
		CommonSettings,
		Undefined);
		
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure DisableNow(Command)
	DisableDetails = True;
	Close();
EndProcedure

&AtClient
Procedure OK(Command)
	Close();
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Function BeforeCloseAtServer(DisableDetails)
	CommonSettings = ReportsOptions.CommonPanelSettings();
	If DisableDetails Then
		CommonSettings.ShowTooltips = False;
	EndIf;
	CommonSettings.ShowTooltipsNotification = False;
	ReportsOptions.SaveCommonPanelSettings(CommonSettings);
	Return CommonSettings;
EndFunction

#EndRegion
