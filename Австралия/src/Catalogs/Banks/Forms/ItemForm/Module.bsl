
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Object.Ref.IsEmpty() Then
		If Parameters.Code <> "" Then
			Object.Code = Parameters.Code;
		EndIf;
		
		FillFormByObject();
	EndIf;
	
	// StandardSubsystems.Properties
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ItemForPlacementName", "GroupAdditionalAttributes");
	PropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.Properties
	If PropertyManagerClient.ProcessNofifications(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributeItems();
		PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.Properties
	PropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	FillFormByObject();
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	CurrentObject.ManualChanging = ?(ManualChanging = Undefined, 2, ManualChanging);
	
	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.Properties
	PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	// Notify the bank account form about the change of bank requisites
	Notify("RecordedItemBank", Object.Ref, ThisForm);

EndProcedure

#Region InteractiveActionResultHandlers

&AtClient
// Procedure-handler of response on the question about data update from classifier
//
Procedure DetermineNecessityForDataUpdateFromClassifier(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		LockFormDataForEdit();
		Modified = True;
		UpdateAtServer();
		NotifyChanged(Object.Ref);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.Properties
&AtClient
Procedure Attachable_PropertiesExecuteCommand(ItemOrCommand, URL = Undefined, StandardProcessing = Undefined)
	
	PropertyManagerClient.ExecuteCommand(ThisObject, ItemOrCommand, StandardProcessing);
	
EndProcedure
// End StandardSubsystems.Properties

#EndRegion

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Change(Command)
	
	Text = NStr("en = 'Record for this bank is automatically kept in sync with the bank classifier. 
	            |If you enable manual modification of bank record, the record will no longer be updated automatically. 
	            |Do you want to edit bank record and disable automatic updates?'; 
	            |ru = 'Элемент справочника для этого банка автоматически обновляется из банковского классификатора.
	            |После ручного изменения элемента автоматическое обновление этого элемента производиться не будет.
	            |Продолжить ручное изменение и отключить автоматическое обновление?';
	            |pl = 'Zapis dla tego banku jest automatycznie synchronizowany z klasyfikatorem banków.
	            |Jeśli włączysz ręczną modyfikację zapisu, zapis nie będzie już aktualizowany automatycznie.
	            |Czy chcesz edytować zapis i wyłączyć automatyczne aktualizacje?';
	            |es_ES = 'Registro para este banco se guarda automáticamente con el clasificador de bancos. 
	            |Si usted activa la modificación manual del registro bancario, el registro no se actualizará más automáticamente.
	            |¿Quiere editar el registro bancario y desactivar las actualizaciones automáticas?';
	            |es_CO = 'Registro para este banco se guarda automáticamente con el clasificador de bancos. 
	            |Si usted activa la modificación manual del registro bancario, el registro no se actualizará más automáticamente.
	            |¿Quiere editar el registro bancario y desactivar las actualizaciones automáticas?';
	            |tr = 'Bu banka için kayıtlar banka sınıflandırıcıyla otomatik olarak senkronize edilir. 
	            |Banka kaydının manuel olarak değiştirilmesini etkinleştirirseniz, kayıt otomatik olarak güncellenmez. 
	            |Banka kaydını düzenlemek ve otomatik güncellemeleri devre dışı bırakmak istiyor musunuz?';
	            |it = 'La registrazione per questa banca viene automaticamente sincronizzata con il classificatore banche. 
	            |Se si attiva la modifica manuale della registrazione di banca, la registrazione non verrà più aggiornata automaticamente. 
	            |Si desidera modificare la registrazione della banca e disabilitare gli aggiornamenti automatici?';
	            |de = 'Der Datensatz für diese Bank wird automatisch mit dem Bankklassifikator synchronisiert.
	            |Wenn Sie die manuelle Änderung des Bankdatensatzes aktivieren, wird der Datensatz nicht mehr automatisch aktualisiert.
	            |Möchten Sie Bankdatensätze bearbeiten und automatische Updates deaktivieren?'");
	Result = Undefined;

	ShowQueryBox(New NotifyDescription("ChangeEnd", ThisObject), Text, QuestionDialogMode.YesNo,, DialogReturnCode.No);
	
EndProcedure

&AtClient
Procedure ChangeEnd(Result1, AdditionalParameters) Export
	
	Result = Result1;
	
	If Result = DialogReturnCode.Yes Then
		
		LockFormDataForEdit();
		Modified		= True;
		ManualChanging	= True;
		
		BankOperationsClientDrive.ProcessManualEditFlag(ThisForm);
		
	EndIf;

EndProcedure

&AtClient
Procedure UpdateFromClassifier(Command)
	
	ExecuteUpdate = False;
	BankOperationsClientDrive.RefreshItemFromClassifier(ThisForm, ExecuteUpdate);
	
EndProcedure

&AtServer
Procedure UpdateAtServer()
	
	BankOperationsDrive.RestoreItemFromSharedData(ThisForm);
	
EndProcedure

#EndRegion

#Region Private

#Region LibrariesHandlers

// StandardSubsystems.Properties

&AtClient
Procedure UpdateAdditionalAttributesDependencies()
	PropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
EndProcedure

&AtClient
Procedure Attachable_OnChangeAdditionalAttribute(Item)
	PropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributeItems()
	PropertyManager.UpdateAdditionalAttributesItems(ThisObject);
EndProcedure

// End StandardSubsystems.Properties

// StandardSubsystems.ObjectAttributesLock

&AtClient
Procedure Attachable_AllowObjectAttributesEditing(Command)
	ObjectAttributesLockClient.AllowObjectAttributeEdit(ThisObject);
EndProcedure

// End StandardSubsystems.ObjectAttributesLock

#EndRegion

&AtServer
Procedure FillFormByObject()
	
	BankOperationsDrive.ReadManualEditFlag(ThisForm);
	
	Items.PagesActivityDiscontinued.CurrentPage = ?(OutOfBusiness,
		Items.PageLabelActivityDiscontinued, Items.PageBlank);
	
EndProcedure

#EndRegion
