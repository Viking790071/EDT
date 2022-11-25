
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If ClientApplication.CurrentInterfaceVariant() = ClientApplicationInterfaceVariant.Version8_2 Then
		Items.FormMarkForDeletion.OnlyInAllActions = False;
	EndIf;
	Items.MoveAllFilesToVolumes.Visible = Common.SubsystemExists("StandardSubsystems.FilesOperations");
	
	If CommonClientServer.IsMobileClient() Then // This is a temporary solution for mobile client. It will be removed from next versions.
		
		Items.Move(Items.CommandBar, Items.CommandBarForm);
		
		Items.CommandBar.Type = FormGroupType.ButtonGroup;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SetClearDeletionMark(Command)
	
	If Items.List.CurrentData = Undefined Then
		Return;
	EndIf;
	
	StartDeletionMarkChange(Items.List.CurrentData);
	
EndProcedure

&AtClient
Procedure MoveAllFilesToVolumes(Command)
	
	FilesOperationsInternalClient.MoveAllFilesToVolumes();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure StartDeletionMarkChange(CurrentData)
	
	If CurrentData.DeletionMark Then
		QuestionText = NStr("ru = 'Снять с ""%1"" пометку на удаление?'; en = 'Do you want to clear a deletion mark for ""%1""?'; pl = 'Oczyścić znacznik usunięcia dla ""%1""?';es_ES = '¿Eliminar la marca para borrar para ""%1""?';es_CO = '¿Eliminar la marca para borrar para ""%1""?';tr = '""%1"" için silme işareti kaldırılsın mı?';it = 'Volete rimuovere il contrassegno per l''eliminazione per ""%1""?';de = 'Löschzeichen für ""%1"" löschen?'");
	Else
		QuestionText = NStr("ru = 'Пометить ""%1"" на удаление?'; en = 'Do you want to mark %1 for deletion?'; pl = 'Zaznaczyć ""%1"" do usunięcia?';es_ES = '¿Marcar ""%1"" para borrar?';es_CO = '¿Marcar ""%1"" para borrar?';tr = '""%1"" silinmek üzere işaretlensin mi?';it = 'Volete contrassegnare %1 per l''eliminazione?';de = 'Markieren Sie ""%1"" zum Löschen?'");
	EndIf;
	
	QuestionContent = New Array;
	QuestionContent.Add(PictureLib.Question32);
	QuestionContent.Add(StringFunctionsClientServer.SubstituteParametersToString(
		QuestionText, CurrentData.Description));
	
	ShowQueryBox(
		New NotifyDescription("ContinueDeletionMarkChange", ThisObject, CurrentData),
		New FormattedString(QuestionContent),
		QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure ContinueDeletionMarkChange(Response, CurrentData) Export
	
	If Response <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	Volume = Items.List.CurrentData.Ref;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Volume", Items.List.CurrentData.Ref);
	AdditionalParameters.Insert("DeletionMark", Undefined);
	AdditionalParameters.Insert("Queries", New Array());
	AdditionalParameters.Insert("FormID", UUID);
	
	PrepareSetClearDeletionMark(Volume, AdditionalParameters);
	
	ContinueNotification = New NotifyDescription(
			"ContinueSetClearDeletionMark", ThisObject, AdditionalParameters);
	
	If CommonClient.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		ModuleSafeModeManagerClient = CommonClient.CommonModule("SafeModeManagerClient");
		ModuleSafeModeManagerClient.ApplyExternalResourceRequests(
			AdditionalParameters.Queries, ThisObject, New NotifyDescription(
				"ContinueSetClearDeletionMark", ThisObject, AdditionalParameters));
			
	Else
		
		ExecuteNotifyProcessing(ContinueNotification, DialogReturnCode.OK);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure PrepareSetClearDeletionMark(Volume, AdditionalParameters)
	
	LockDataForEdit(Volume, , AdditionalParameters.FormID);
	
	VolumeProperties = Common.ObjectAttributesValues(
		Volume, "DeletionMark,FullPathWindows,FullPathLinux");
	
	AdditionalParameters.DeletionMark = VolumeProperties.DeletionMark;
	
	If AdditionalParameters.DeletionMark Then
		// Deletion mark is set, and it is to be cleared.
		
		Query = Catalogs.FileStorageVolumes.RequestToUseExternalResourcesForVolume(
			Volume, VolumeProperties.FullPathWindows, VolumeProperties.FullPathLinux);
	Else
		// Deletion mark is not set, and it is to be set.
		If Common.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
			ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
			Query = ModuleSafeModeManager.RequestToClearPermissionsToUseExternalResources(Volume)
		EndIf;
	EndIf;
	
	AdditionalParameters.Queries.Add(Query);
	
EndProcedure

&AtClient
Procedure ContinueSetClearDeletionMark(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.OK Then
		
		EndSetClearDeletionMark(AdditionalParameters);
		Items.List.Refresh();
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure EndSetClearDeletionMark(AdditionalParameters)
	
	BeginTransaction();
	Try
	
		DataLock = New DataLock;
		DataLockItem = DataLock.Add(Metadata.Catalogs.FileStorageVolumes.FullName());
		DataLockItem.SetValue("Ref", AdditionalParameters.Volume);
		DataLock.Lock();
		
		Object = AdditionalParameters.Volume.GetObject();
		Object.SetDeletionMark(Not AdditionalParameters.DeletionMark);
		Object.Write();
		
		UnlockDataForEdit(
		AdditionalParameters.Volume, AdditionalParameters.FormID);
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#EndRegion