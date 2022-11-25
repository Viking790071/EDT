#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Key.IsEmpty() Then
		SetVariantItemsVisibility();
		SetBatchItemsVisibility();
	EndIf;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	Notify("Write_ProductsCategory", Object.Ref);
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	SetVariantItemsVisibility();
	SetBatchItemsVisibility();
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure UseMatrixSelectionFormOnChange(Item)
	
	If Not DriveClient.UseMatrixFormWithCategory(Object.Ref) Then
		
		CommonClientServer.MessageToUser(NStr("en = 'Matrix form is available only for two dimensions'; ru = 'Матричная форма доступна только для двух измерений';pl = 'Formularz matrycy jest dostępny tylko w dwóch wymiarach';es_ES = 'El formulario de matriz está disponible sólo para dos dimensiones';es_CO = 'El formulario de matriz está disponible sólo para dos dimensiones';tr = 'Matris formu yalnızca iki boyut için kullanılabilir';it = 'Modulo matrice disponibile solo per due dimensioni';de = 'Die Matrixform ist nur für zwei Dimensionen verfügbar'"))
		
	EndIf;
	
EndProcedure

&AtClient
Procedure UseCharacteristicsOnChange(Item)
	
	SetVariantItemsVisibility();
	
EndProcedure

&AtClient
Procedure UseBatchesOnChange(Item)
	
	SetBatchItemsVisibility();
	
EndProcedure

&AtClient
Procedure ConfigureCharacteristicsAttributesSetClick(Item)
	
	If Not ValueIsFilled(Object.SetOfCharacteristicProperties) Then
		
		QuestionText = NStr("en = 'You can edit properties only after saving. Do you wish to save?'; ru = 'Чтобы редактировать свойства, нужно сохранить изменений. Сохранить?';pl = 'Możesz edytować właściwości tylko po zapisaniu. Czy chcesz zapisać?';es_ES = 'Usted puede editar propiedades solo después de haberlas guardado. ¿Quiere guardar?';es_CO = 'Usted puede editar propiedades solo después de haberlas guardado. ¿Quiere guardar?';tr = 'Özellikler yalnızca kaydedildikten sonra düzenlenebilir. Kaydetmek ister misiniz?';it = 'È possibile modificare le proprietà solo dopo il salvataggio. Salvare?';de = 'Sie können Eigenschaften erst nach dem Speichern bearbeiten. Möchten Sie speichern?'");
		
		Notification = New NotifyDescription("ConfigureSetOfPropertiesCharacteristicsClickEnd", ThisForm);
		ShowQueryBox(Notification, QuestionText, QuestionDialogMode.OKCancel,, DialogReturnCode.Cancel, 
			NStr("en = 'Edit properties'; ru = 'Редактирование свойств';pl = 'Edytuj właściwości';es_ES = 'Editar propiedades';es_CO = 'Editar propiedades';tr = 'Özellikleri düzenle';it = 'Modificare proprietà';de = 'Eigenschaften bearbeiten'"));
		
		Return;
		
	EndIf;
	
	OpenAdditionalSetsForm(Object.SetOfCharacteristicProperties);
	
EndProcedure

&AtClient
Procedure ConfigureAttributesSetClick(Item)
	
	If Not ValueIsFilled(Object.PropertySet) Then
		
		QuestionText = NStr("en = 'You can edit attributes only after saving. Do you wish to save?'; ru = 'Редактирование набора реквизитов возможно только после записи элемента, записать элемент?';pl = 'Możesz edytować atrybuty tylko po zapisaniu. Czy chcesz zapisać?';es_ES = 'Usted puede editar los atributos solo después de haberlos guardado. ¿Quiere guardar?';es_CO = 'Usted puede editar los atributos solo después de haberlos guardado. ¿Quiere guardar?';tr = 'Öznitelikler yalnızca kaydedildikten sonra düzenlenebilir. Kaydetmek ister misiniz?';it = 'È possibile modificare gli attributi solo dopo il salvataggio. Salvare?';de = 'Sie können Attribute erst nach dem Speichern bearbeiten. Möchten Sie speichern?'");
		
		Notification = New NotifyDescription("ConfigurePropertySetClickEnd", ThisForm);
		ShowQueryBox(Notification, QuestionText, QuestionDialogMode.OKCancel,, DialogReturnCode.Cancel, 
			NStr("en = 'Edit attributes'; ru = 'Редактирование набора реквизитов';pl = 'Edytuj atrybuty';es_ES = 'Editar atributos';es_CO = 'Editar atributos';tr = 'Öznitelikleri düzenle';it = 'Modificare gli attributi';de = 'Attribute bearbeiten'"));
		
		Return;
		
	EndIf;
	
	OpenAdditionalSetsForm(Object.PropertySet);

EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetVariantItemsVisibility()
	
	UseCharacteristics	= GetFunctionalOption("UseCharacteristics");
	
	Items.ConfigureCharacteristicsAttributesSet.Visible = UseCharacteristics And Object.UseCharacteristics;
	If UseCharacteristics Then
		Items.UseMatrixSelectionForm.Visible = Object.UseCharacteristics;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetBatchItemsVisibility()
	
	Items.BatchSettings.Visible = Object.UseBatches;
	
EndProcedure

&AtClient
Procedure ConfigureSetOfPropertiesCharacteristicsClickEnd(Response, Parameters) Export
	
	If Response = DialogReturnCode.Cancel
		OR Not Write() Then
			Return;
	EndIf;
	
	OpenAdditionalSetsForm(Object.SetOfCharacteristicProperties);
	
EndProcedure

&AtClient
Procedure ConfigurePropertySetClickEnd(Response, Parameters) Export
	
	If Response = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	If Not Write() Then
		Return;
	EndIf;
	
	OpenAdditionalSetsForm(Object.PropertySet);
	
EndProcedure

&AtClient
Procedure OpenAdditionalSetsForm(CurrentSet)
	OpenForm("Catalog.AdditionalAttributesAndInfoSets.ListForm", New Structure("CurrentRow", CurrentSet));
EndProcedure

#Region LibrariesHandlers

&AtClient
Procedure Attachable_AllowObjectAttributesEditing(Command)
	
	ObjectAttributesLockClient.AllowObjectAttributeEdit(ThisObject);
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#EndRegion

