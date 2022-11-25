
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If ValueIsFilled(Parameters.FileOwner) Then 
		List.Parameters.SetParameterValue(
			"Owner", Parameters.FileOwner);
	
		If TypeOf(Parameters.FileOwner) = Type("CatalogRef.FileFolders") Then
			Items.Folders.CurrentRow = Parameters.FileOwner;
			Items.Folders.SelectedRows.Clear();
			Items.Folders.SelectedRows.Add(Items.Folders.CurrentRow);
		Else
			Items.Folders.Visible = False;
		EndIf;
	Else
		If Parameters.SelectTemplate Then
			
			DefinePossibilityAddFilesTemplates();
			
			TemplateSelectionMode = Parameters.SelectTemplate;
			
			CommonClientServer.SetDynamicListFilterItem(
				Folders, "Ref", Catalogs.FileFolders.Templates,
				DataCompositionComparisonType.InHierarchy, , True);
			
			Items.Folders.CurrentRow = Catalogs.FileFolders.Templates;
			Items.Folders.SelectedRows.Clear();
			Items.Folders.SelectedRows.Add(Items.Folders.CurrentRow);
		EndIf;
		
		List.Parameters.SetParameterValue("Owner", Items.Folders.CurrentRow);
	EndIf;
	
	If ValueIsFilled(Parameters.CurrentRow) Then 
		Items.Folders.CurrentRow = Parameters.CurrentRow;
	EndIf;
	
	OnChangeUseSignOrEncryptionAtServer();
	
EndProcedure


&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_File" AND Parameter.Property("IsNew") AND Parameter.IsNew Then
		
		If Parameter <> Undefined Then
			FileOwner = Undefined;
			If Parameter.Property("Owner", FileOwner) Then
				If FileOwner = Items.Folders.CurrentRow Then
					Items.List.Refresh();
					
					CreatedFile = Undefined;
					If Parameter.Property("File", CreatedFile) Then
						Items.List.CurrentRow = CreatedFile;
					EndIf;
				EndIf;
			EndIf;
		EndIf;
		
		Items.List.Refresh();
		
	EndIf;
	
	If Upper(EventName) = Upper("Write_ConstantsSet")
		AND (    Upper(Source) = Upper("UseDigitalSignature")
		Or Upper(Source) = Upper("UseEncryption")) Then
		
		AttachIdleHandler("OnChangeSignatureOrEncryptionUsage", 0.3, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region FolderFormTableItemsEventHandlers

&AtClient
Procedure FoldersOnActivateRow(Item)
	AttachIdleHandler("IdleHandler", 0.2, True);
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder, Parameter)
	
	Cancel = True;
	If Not Clone Then
		AddFileToApplication();
	EndIf;
	
EndProcedure

&AtClient
Procedure ListBeforeDelete(Item, Cancel)
	Cancel = True;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure AppendFile(Command)
	
	AddFileToApplication();
	
EndProcedure

&AtClient
Procedure AddFileToApplication()
	
	If TemplateSelectionMode Then
		
		FilesOperationsInternalClient.AddFileFromFileSystem(Items.Folders.CurrentRow, ThisObject);
		
	Else
		
		DCParameterValue = List.Parameters.FindParameterValue(New DataCompositionParameter("Owner"));
		If DCParameterValue = Undefined Then
			FileOwner = Undefined;
		Else
			FileOwner = DCParameterValue.Value;
		EndIf;
		FilesOperationsInternalClient.AppendFile(Undefined, FileOwner, ThisObject);
		
	EndIf;

EndProcedure

#EndRegion

#Region Private

// The procedure updates the Files list.
&AtClient
Procedure IdleHandler()
	
	If Items.Folders.CurrentRow <> Undefined Then
		List.Parameters.SetParameterValue("Owner", Items.Folders.CurrentRow);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnChangeSignatureOrEncryptionUsage()
	
	OnChangeUseSignOrEncryptionAtServer();
	
EndProcedure

&AtServer
Procedure OnChangeUseSignOrEncryptionAtServer()
	
	FilesOperationsInternal.CryptographyOnCreateFormAtServer(ThisObject,, True);
	
EndProcedure

&AtServer
Procedure DefinePossibilityAddFilesTemplates()
	
	Var HasRightAddFiles, ModuleAccessManagement;
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		HasRightAddFiles = ModuleAccessManagement.HasRight("AddFiles", Catalogs.FileFolders.Templates);
	Else
		HasRightAddFiles = AccessRight("Insert", Metadata.Catalogs.Files) AND AccessRight("Read", Metadata.Catalogs.FileFolders);
	EndIf;
	
	If Not HasRightAddFiles Then
		Items.AppendFile.Visible = False;
	EndIf;

EndProcedure

#EndRegion
