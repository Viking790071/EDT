#Region Variables

&AtClient
Var RefreshInterface;

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Visibility settings at startup.
	Items.Extensions.Visible = Not StandardSubsystemsServer.IsBaseConfigurationVersion();
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		DataSeparationEnabled = Common.DataSeparationEnabled();
		Items.UseAdditionalReportsAndDataProcessors.Visible = Not DataSeparationEnabled;
		Items.OpenAdditionalReportsAndDataProcessors.Visible      = Not DataSeparationEnabled
			// When working in a SaaS mode if it is enabled by the service administrator.
			Or ConstantsSet.UseAdditionalReportsAndDataProcessors;
	Else
		Items.AdditionalReportsAndDataProcessorsGroup.Visible = False;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ReportMailing") Then
		ModuleReportDistribution = Common.CommonModule("ReportMailing");
		Items.OpenReportsBulkEmails.Visible = ModuleReportDistribution.InsertRight();
	Else
		Items.ReportsBulkEmailsGroup.Visible = False;
	EndIf;
	
	// Update items states.
	SetAvailability();
	
	ApplicationSettingsOverridable.PrintFormsReportsAndDataProcessorsOnCreateAtServer(ThisObject);
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	If Exit Then
		Return;
	EndIf;
	UpdateApplicationInterface();
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure UseAdditionalReportsAndDataProcessorsOnChange(Item)
	
	PreviousValue = ConstantsSet.UseAdditionalReportsAndDataProcessors;
	
	Try
		
		Handler = New NotifyDescription("UseAdditionalReportsAndDataProcessorsOnChangeCompletion", ThisObject, Item);
		If CommonClient.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
			RequestToUseExternalResources = RequestToUseExternalResourcesOfAdditionalReportsAndDataProcessors(PreviousValue);
			ModuleSafeModeManagerClient = CommonClient.CommonModule("SafeModeManagerClient");
			ModuleSafeModeManagerClient.ApplyExternalResourceRequests(RequestToUseExternalResources, ThisObject, Handler);
		Else
			ExecuteNotifyProcessing(Handler, DialogReturnCode.OK);
		EndIf;
		
	Except
		
		ConstantsSet.UseAdditionalReportsAndDataProcessors = PreviousValue;
		Raise;
		
	EndTry;
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Client

&AtClient
Procedure Attachable_OnChangeAttribute(Item, UpdateInterface = True)
	
	ConstantName = OnChangeAttributeServer(Item.Name);
	
	RefreshReusableValues();
	
	If UpdateInterface Then
		RefreshInterface = True;
		AttachIdleHandler("UpdateApplicationInterface", 2, True);
	EndIf;
	
	If ConstantName <> "" Then
		Notify("Write_ConstantsSet", New Structure, ConstantName);
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateApplicationInterface()
	
	If RefreshInterface = True Then
		RefreshInterface = False;
		CommonClient.RefreshApplicationInterface();
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Server call

&AtServer
Function OnChangeAttributeServer(ItemName)
	
	DataPathAttribute = Items[ItemName].DataPath;
	
	ConstantName = SaveAttributeValue(DataPathAttribute);
	
	SetAvailability(DataPathAttribute);
	
	RefreshReusableValues();
	
	Return ConstantName;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Server

&AtServer
Function SaveAttributeValue(DataPathAttribute)
	
	// Save values of attributes not directly related to constants (in ratio one to one).
	If DataPathAttribute = "" Then
		Return "";
	EndIf;
	
	// Define the constant name.
	ConstantName = "";
	Position = StrFind(DataPathAttribute, "ConstantsSet.");
	If Position > 0 Then
		ConstantName = StrReplace(DataPathAttribute, "ConstantsSet.", "");
	Else
		// Define the name and record the attribute value in the constant from the ConstantsSet.
		// It is used for those form attributes that are directly related to constants (in ratio one to one).
	EndIf;
	
	// Save the constant value.
	If ConstantName <> "" Then
		ConstantManager = Constants[ConstantName];
		ConstantValue = ConstantsSet[ConstantName];
		
		If ConstantManager.Get() <> ConstantValue Then
			ConstantManager.Set(ConstantValue);
		EndIf;
	EndIf;
	
	Return ConstantName;
	
EndFunction

&AtServer
Procedure SetAvailability(DataPathAttribute = "")
	
	If DataPathAttribute = "ConstantsSet.UseAdditionalReportsAndDataProcessors" OR DataPathAttribute = ""
		AND Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		Items.OpenAdditionalReportsAndDataProcessors.Enabled = ConstantsSet.UseAdditionalReportsAndDataProcessors;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function RequestToUseExternalResourcesOfAdditionalReportsAndDataProcessors(Include)
	
	ModuleAdditionalReportsAndDataProcessorsSafeModeInternal = Common.CommonModule(
		"AdditionalReportsAndDataProcessorsSafeModeInternal");
	Return ModuleAdditionalReportsAndDataProcessorsSafeModeInternal.AdditionalDataProcessorsPermissionRequests(Include);
	
EndFunction

&AtClient
Procedure UseAdditionalReportsAndDataProcessorsOnChangeCompletion(Response, Item) Export
	
	If Response <> DialogReturnCode.OK Then
		ConstantsSet.UseAdditionalReportsAndDataProcessors = Not ConstantsSet.UseAdditionalReportsAndDataProcessors;
	Else
		Attachable_OnChangeAttribute(Item);
	EndIf;
	
EndProcedure

&AtClient
Procedure DisplayPrintOptionsBeforePrintingOnChange(Item)
    
    Attachable_OnChangeAttribute(Item);
    
EndProcedure

#EndRegion
