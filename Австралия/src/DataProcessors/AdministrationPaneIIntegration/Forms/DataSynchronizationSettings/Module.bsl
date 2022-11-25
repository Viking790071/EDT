#Region Variables

&AtClient
Var RefreshInterface;

#EndRegion

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	CheckContractsOnPosting = ?(ConstantsSet.CheckContractsOnPosting,
		Enums.YesNo.Yes,
		Enums.YesNo.No);
	
	// Settings of visible on launch
	Items.GroupTemporaryDirectoriesServersCluster.Visible = RunMode.ClientServer AND RunMode.ThisIsSystemAdministrator;
	Items.AdditionalInformation.Visible = RunMode.SaaS;
	
	If RunMode.SaaS Then
		
		Items.GroupUseDataSync.Visible = False;
		Items.GroupDistributedInfobaseNodePrefix.Visible = False;
		Items.GroupTemporaryDirectoriesServersCluster.Visible = False;
		
	EndIf;
	
	// Update items states
	SetEnabled();
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	AlertsHandler(EventName, Parameter, Source);
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	#If Not WebClient Then
		RefreshApplicationInterface();
	#EndIf

EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure HowToApplySettingsNavigationRefProcessing(Item, URL, StandardProcessing)
	StandardProcessing = False;
	RefreshInterface = True;
	AttachIdleHandler("RefreshApplicationInterface", 0.1, True);
EndProcedure

&AtClient
Procedure UseDataSyncOnChange(Item)
	
	UpdateSecurityProfilesPermissions(Item);
	
EndProcedure

&AtClient
Procedure DistributedInformationBaseNodePrefixOnChange(Item)
	Attachable_OnAttributeChange(Item);
EndProcedure

&AtClient
Procedure DataExchangeMessagesDirectoryForWindowsOnChange(Item)
	
	UpdateSecurityProfilesPermissions(Item);
	
EndProcedure

&AtClient
Procedure DataExchangeMessagesDirectoryForLinuxOnChange(Item)
	
	UpdateSecurityProfilesPermissions(Item);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure AlertsHandler(EventName, Parameter, Source)
	
	// Data processor of alerts from other open forms.
	//
	// Example:
	//   If EventName =
	//     "ConstantsSet.DistributedInfobaseNodePrefix" Then ConstantsSet.DistributedInfobaseNodePrefix = Parameter;
	//   EndIf;
	
	
	
EndProcedure

&AtClient
Procedure DataSynchronizationSettings(Command)
	
	If RunMode.SaaS Then
		
		OpenableFormName = "CommonForm.DataSyncSaaS";
		
	Else
		OpenableFormName = "CommonForm.DataSync";
		
	EndIf;
	
	OpenForm(OpenableFormName);
	
EndProcedure

&AtClient
Procedure InformationRegisterDataImportProhibitionDates(Command)
	OpenForm(
		"InformationRegister.PeriodClosingDates.Form.PeriodClosingDates",
		New Structure("DataClosingDatesOfDataImport", True),
		ThisObject);
EndProcedure

&AtClient
Procedure ResultsSynchronizationData(Command)
	OpenForm("InformationRegister.DataExchangeResults.Form.Form");
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

#Region Client

&AtClient
Procedure Attachable_OnAttributeChange(Item, RefreshingInterface = True)
	
	Result = OnAttributeChangeServer(Item.Name);
	
	If RefreshingInterface Then
		RefreshInterface = True;
		AttachIdleHandler("RefreshApplicationInterface", 1, True);
	EndIf;
	
	DriveClient.ShowExecutionResult(ThisObject, Result);
	
EndProcedure

&AtClient
Procedure RefreshApplicationInterface()
	
	If RefreshInterface = True Then
		RefreshInterface = False;
		CommonClient.RefreshApplicationInterface();
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateSecurityProfilesPermissions(Item)
	
	ClosingAlert = New NotifyDescription("UpdateSecurityProfilesPermissionsEnd", ThisObject, Item);
	
	ArrayOfQueries = CreateQueryOnExternalResourcesUse(Item.Name);
	
	If ArrayOfQueries = Undefined Then
		Return;
	EndIf;
	
	ModuleWorkInSafeModeClient = CommonClient.CommonModule("WorkInSafeModeClient");
	ModuleWorkInSafeModeClient.ApplyQueriesOnExternalResourcesUse(
			ArrayOfQueries, ThisObject, ClosingAlert);
	
EndProcedure

&AtServer
Function CreateQueryOnExternalResourcesUse(ConstantName)
	
	ConstantManager = Constants[ConstantName];
	ConstantValue = ConstantsSet[ConstantName];
	
	If ConstantManager.Get() = ConstantValue Then
		Return Undefined;
	EndIf;
	
	If ConstantName = "UseDataSynchronization" Then
		
		If ConstantValue Then
			
			Query = DataExchangeServer.RequestToUseExternalResourcesOnEnableExchange();
			
		Else
			
			Query = DataExchangeServer.RequestToClearPermissionsToUseExternalResources();
			
		EndIf;
		
		Return Query;
		
	Else
		
		ValueManager = ConstantManager.CreateValueManager();
		ConstantIdentifier = Common.MetadataObjectID(ValueManager.Metadata());
		
		ModuleWorkInSafeMode = Common.CommonModule("WorkInSafeMode");
		If IsBlankString(ConstantValue) Then
			
			Query = ModuleWorkInSafeMode.QueryOnClearPermissionToUseExternalResources(ConstantIdentifier);
			
		Else
			
			permissions = CommonClientServer.ValueInArray(
				ModuleWorkInSafeMode.PermissionToUseFileSystemDirectory(ConstantValue, True, True));
			Query = ModuleWorkInSafeMode.QueryOnExternalResourcesUse(permissions, ConstantIdentifier);
			
		EndIf;
		
		Return CommonClientServer.ValueInArray(Query);
		
	EndIf;
	
EndFunction

&AtClient
Procedure UpdateSecurityProfilesPermissionsEnd(Result, Item) Export
	
	If Result = DialogReturnCode.OK Then
	
		Attachable_OnAttributeChange(Item);
		
	Else
		
		ThisObject.Read();
	
	EndIf;
	
EndProcedure

#EndRegion

#Region CallingTheServer

&AtServer
Function OnAttributeChangeServer(ItemName)
	
	Result = New Structure;
	
	AttributePathToData = Items[ItemName].DataPath;
	
	ConstantName = SaveAttributeValue(AttributePathToData);
	
	SetEnabled(AttributePathToData);
	
	RefreshReusableValues();
	
	Return Result;
	
EndFunction

#EndRegion

#Region Server

&AtServer
Function SaveAttributeValue(AttributePathToData)
	
	// Save attribute values not connected with constants directly (one-to-one ratio).
	If AttributePathToData = "" Then
		Return "";
	EndIf;
	
	// Definition of constant name.
	ConstantName = "";
	If Lower(Left(AttributePathToData, 13)) = Lower("ConstantsSet.") Then
		// If the path to attribute data is specified through "ConstantsSet".
		ConstantName = Mid(AttributePathToData, 14);
	Else
		// Definition of name and attribute value record in the corresponding constant from "ConstantsSet".
		// Used for the attributes of the form directly connected with constants (one-to-one ratio).
	EndIf;
	
	// Saving the constant value.
	If ConstantName <> "" Then
		ConstantManager = Constants[ConstantName];
		ConstantValue = ConstantsSet[ConstantName];
		
		If ConstantManager.Get() <> ConstantValue Then
			ConstantManager.Set(ConstantValue);
		EndIf;
		
	EndIf;
	
	If AttributePathToData = "CheckContractsOnPosting" Then
		
		ConstantValue = (CheckContractsOnPosting = Enums.YesNo.Yes);
		Constants.CheckContractsOnPosting.Set(ConstantValue);
		
	EndIf;
	
	Return ConstantName;
	
EndFunction

&AtServer
Procedure SetEnabled(AttributePathToData = "")
	
	If AttributePathToData = "ConstantsSet.UseDataSync" OR AttributePathToData = "" Then
		
		CommonClientServer.SetFormItemProperty(Items, "ResultsSynchronizationData", 					"Enabled", ConstantsSet.UseDataSync);
		CommonClientServer.SetFormItemProperty(Items, "GroupDistributedInfobaseNodePrefix",	"Enabled", ConstantsSet.UseDataSync);
		CommonClientServer.SetFormItemProperty(Items, "DataSynchronizationSettings",						"Enabled", ConstantsSet.UseDataSync);
		CommonClientServer.SetFormItemProperty(Items, "ResultsSynchronizationData",						"Enabled", ConstantsSet.UseDataSync);
		CommonClientServer.SetFormItemProperty(Items, "GroupTemporaryDirectoriesServersCluster",			"Enabled", ConstantsSet.UseDataSync);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfFormAttributes

&AtClient
Procedure ControlContractsOnDocumentsPostingOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure DecorationInformationAboutSynchronizationWithPSUClick(Item)
	GotoURL("");
EndProcedure

&AtClient
Procedure DecorationInformationAboutSynchronizationWithERClick(Item)
	GotoURL("");
EndProcedure

#EndRegion

#EndRegion
