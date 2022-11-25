#Region ProcedureFormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	StandardProcessing = False;
	
	If Parameters.Property("BeginOfPeriod") Then
		
		BeginOfPeriod = Parameters["BeginOfPeriod"];
		SetParameterAtServer("BeginOfPeriod", BeginOfPeriod);
		
	EndIf;
	
	If Parameters.Property("EndOfPeriod") Then
		
		EndOfPeriod = Parameters["EndOfPeriod"];
		SetParameterAtServer("EndOfPeriod", EndOfPeriod);
		
	EndIf;
	
	If Parameters.Property("Company") Then
		
		Company = Parameters["Company"];
		SetParameterAtServer("Company", Company);
		
	Else
		
		Cancel = True;
		
	EndIf;
	
	If Parameters.Property("GeneratingDate") Then
		
		GeneratingDate = Parameters["GeneratingDate"];
		SetParameterAtServer("GeneratingDate", GeneratingDate);
		
	EndIf;
	
	Items.MainCommandBar.Visible = False;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	ComposeResult();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetParameterAtServer(ParameterName, ParameterValue)
	
	CompositionSetup	= Report.SettingsComposer.Settings;
	FoundSetting	= CompositionSetup.DataParameters.Items.Find(ParameterName);
	
	If Not FoundSetting = Undefined Then
		
		FoundSetting.Use = True;
		FoundSetting.Value = ParameterValue;
		
		UserSettingsItem = Report.SettingsComposer.UserSettings.Items.Find(FoundSetting.UserSettingID);
		If UserSettingsItem <> Undefined Then
			UserSettingsItem.Use = True;
			UserSettingsItem.Value = ParameterValue;
		EndIf;
		
	ElsIf NOT FoundSetting = Undefined Then
		
		FoundSetting.Use = True;
		FoundSetting.Value = ParameterValue;
		
	EndIf;
	
EndProcedure

#EndRegion