
#Region Variables

&AtClient
Var RefreshInterface;

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure Attachable_OnAttributeChange(Item, RefreshingInterface = True)
	
	Result = OnAttributeChangeServer(Item.Name);
	
	If RefreshingInterface Then
		
		AttachIdleHandler("RefreshApplicationInterface", 1, True);
		RefreshInterface = True;
	
	EndIf;
	
	If Result.Property("NotificationForms") Then
		Notify(Result.NotificationForms.EventName, Result.NotificationForms.Parameter, Result.NotificationForms.Source);
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshApplicationInterface()
	
	If RefreshInterface = True Then
		RefreshInterface = False;
		RefreshInterface();
	EndIf;
	
EndProcedure

&AtServer
Procedure SetEnabled(AttributePathToData = "")
	
	
	
EndProcedure

&AtServer
Function OnAttributeChangeServer(ItemName)
	
	Result = New Structure;
	
	AttributePathToData = Items[ItemName].DataPath;
	
	SaveAttributeValue(AttributePathToData, Result);
	
	ReadValuesFromStoreCommonSettings(AttributePathToData);
	
	SetEnabled(AttributePathToData);
	
	RefreshReusableValues();
	
	Return Result;
	
EndFunction

&AtServer
Procedure SaveAttributeValue(AttributePathToData, Result)
	
	// Save attribute values not connected with constants directly (one-to-one ratio).
	If AttributePathToData = "" Then
		Return;
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
		
		NotificationForms = New Structure("EventName, Parameter, Source", "Record_ConstantsSet", New Structure, ConstantName);
		Result.Insert("NotificationForms", NotificationForms);
	EndIf;
	
	If AttributePathToData = "DoubleClickAction" Then
		
		CommonSettingsStorage.Save("OpenFileSettings", "DoubleClickAction", DoubleClickAction);
		
	EndIf;
	
	If AttributePathToData = "PromptForEditModeOnOpenFile" Then
		
		CommonSettingsStorage.Save("OpenFileSettings", "PromptForEditModeOnOpenFile", PromptForEditModeOnOpenFile);
		
	EndIf;
	
	If AttributePathToData = "ShowFileEditTips" Then
		
		CommonSettingsStorage.Save("OpenFileSettings", "ShowFileEditTips", ShowFileEditTips);
		
	EndIf;
	
	If AttributePathToData = "ShowLockedFilesOnExit" Then
		
		CommonSettingsStorage.Save("ApplicationSettings", "ShowLockedFilesOnExit", ShowLockedFilesOnExit);
		
	EndIf;
	
	If AttributePathToData = "ShowColumnSize" Then
		
		CommonSettingsStorage.Save("ApplicationSettings", "ShowColumnSize", ShowColumnSize);
		
	EndIf;
	
	If AttributePathToData = "FileVersionComparisonMethod" Then
		
		CommonSettingsStorage.Save("FileComparisonSettings", "FileVersionComparisonMethod", FileVersionComparisonMethod);
		
	EndIf;
	
EndProcedure

// Read values from common settings storage
//
&AtServer
Procedure ReadValuesFromStoreCommonSettings(AttributePathToData = "")
	
	If AttributePathToData = "DoubleClickAction" OR IsBlankString(AttributePathToData) Then
	
		DoubleClickAction = Common.CommonSettingsStorageLoad("OpenFileSettings", "DoubleClickAction");
		If DoubleClickAction = Undefined Then
			
			DoubleClickAction = Enums.DoubleClickFileActions.OpenFile;
			SaveAttributeValue("DoubleClickAction", DoubleClickAction);
			
		EndIf;
		
	EndIf;
	
	If AttributePathToData = "PromptForEditModeOnOpenFile" OR IsBlankString(AttributePathToData) Then
		
		PromptForEditModeOnOpenFile = Common.CommonSettingsStorageLoad("OpenFileSettings", "PromptForEditModeOnOpenFile");
		If PromptForEditModeOnOpenFile = Undefined Then
			
			PromptForEditModeOnOpenFile = True;
			SaveAttributeValue("PromptForEditModeOnOpenFile", PromptForEditModeOnOpenFile);
			
		EndIf;
		
	EndIf;
	
	If AttributePathToData = "ShowFileEditTips" OR IsBlankString(AttributePathToData) Then
		
		ShowFileEditTips = Common.CommonSettingsStorageLoad("OpenFileSettings", "ShowFileEditTips");
		If ShowFileEditTips = Undefined Then
			
			ShowFileEditTips = True;
			SaveAttributeValue("ShowFileEditTips", ShowFileEditTips);
			
		EndIf;
		
	EndIf;
	
	If AttributePathToData = "ShowLockedFilesOnExit" OR IsBlankString(AttributePathToData) Then
		
		ShowLockedFilesOnExit = Common.CommonSettingsStorageLoad("ApplicationSettings", "ShowLockedFilesOnExit");
		If ShowLockedFilesOnExit = Undefined Then 
			
			ShowLockedFilesOnExit = True;
			SaveAttributeValue("ShowLockedFilesOnExit", ShowLockedFilesOnExit);
			
		EndIf;
		
	EndIf;
	
	If AttributePathToData = "ShowColumnSize" OR IsBlankString(AttributePathToData) Then
		
		ShowColumnSize = Common.CommonSettingsStorageLoad("ApplicationSettings", "ShowColumnSize");
		If ShowColumnSize = Undefined Then
			
			ShowColumnSize = False;
			SaveAttributeValue("ShowColumnSize", ShowColumnSize);
			
		EndIf;
		
	EndIf;
	
	If AttributePathToData = "FileVersionComparisonMethod" OR IsBlankString(AttributePathToData) Then
		
		FileVersionComparisonMethod = Common.CommonSettingsStorageLoad("FileComparisonSettings", "FileVersionComparisonMethod");
		If Not ValueIsFilled(FileVersionComparisonMethod) Then
			
			FileVersionComparisonMethod = Enums.FileVersionsComparisonMethods.MicrosoftOfficeWord;
			SaveAttributeValue("FileVersionComparisonMethod", FileVersionComparisonMethod);
			
		EndIf;
		
	EndIf;
	
		
EndProcedure

#Region FormCommandHandlers

&AtClient
Procedure WorkingDirectorySetting(Command)
	
	OpenForm("CommonForm.WorkingDirectorySettings");
	
EndProcedure

&AtClient
Procedure ScanningSetup(Command)
	
	AddInInstalled = WorkWithScannerClient.InitializeComponent();
	
	SystemInfo = New SystemInfo();
	ClientID = SystemInfo.ClientID;
	
	FormParameters = New Structure("AddInInstalled, ClientID", AddInInstalled, ClientID);
	
	OpenForm("DataProcessor.Scanning.Form.ScanningSettings", FormParameters);
	
EndProcedure

&AtClient
Procedure InstallCryptoExtensionAtClient(Command)
	
	BeginInstallCryptoExtension(Undefined);
	
EndProcedure

// Procedure - command handler OpenAttachedFilesList
//
&AtClient
Procedure AttachedFilesOpenList(Command)
	
	OpenForm("Catalog.Files.Form.Files");
	
EndProcedure

// Procedure - command handler OpenEditableFilesList
//
&AtClient
Procedure OpenListOfEditableFiles(Command)
	
	OpenForm("DataProcessor.FilesOperations.Form.FilesToEdit");
	
EndProcedure

#EndRegion

#EndRegion

#Region ProcedureFormEventHandlers

// Procedure - OnCreateAtServer form event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Work with files
	ReadValuesFromStoreCommonSettings();
	
	SetEnabled();
	
EndProcedure

// Procedure - event handler ChoiceProcessing of form.
//
&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If ChoiceSource.FormName = "Enum.DoubleClickFileActions.ChoiceForm" 
		AND ValueIsFilled(ValueSelected)
		AND ValueSelected <> DoubleClickAction Then
		
		DoubleClickAction = ValueSelected;
		Attachable_OnAttributeChange(Items.DoubleClickAction);
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnClose form.
&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	RefreshApplicationInterface();
	
EndProcedure

#Region ProcedureEventHandlersOfFormAttributes

// Procedure - event handler Clicking the field DoubleClickAction
// 
&AtClient
Procedure DoubleClickActionClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenForm("Enum.DoubleClickFileActions.ChoiceForm", , ThisForm);
	
EndProcedure

// Procedure - event handler OnChange field AskEditModeOnOpenFile
//
&AtClient
Procedure AskEditModeOnOpenFileOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange field ShowToolTipsWhenEditingFiles
//
&AtClient
Procedure ShowToolTipsWhenYouEditFilesOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange field ShowLockedFilesOnExit
//
&AtClient
Procedure ShowLockedFilesOnCompleteWorksOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange field ShowColumnSize
//
&AtClient
Procedure ShowSizeColumnOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure FileVersionComparisonMethodOnChange(Item)
	
	Attachable_OnAttributeChange(Items.FileVersionComparisonMethod);
	
EndProcedure

#EndRegion

#EndRegion
