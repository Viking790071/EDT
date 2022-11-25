
#Region FormEventsHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	VerifyAccessRights("SaveUserData", Metadata);
	
	StructureOfCIAttributesAndKinds = New Structure;
	
	AddContactInformationAttributes();
	LoadSettings();
	
EndProcedure

// Procedure - event  handler BeforeClose.
//
&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)

	If Modified Then
		
		If Exit Then
			WarningText = NStr("en = 'Data changed. All changes will be lost.'; ru = 'Данные были изменены. Все изменения будут потеряны.';pl = 'Dane zostały zmienione. Wszystkie zmiany zostaną utracone.';es_ES = 'Datos cambiados. Todos los cambios se perderán.';es_CO = 'Datos cambiados. Todos los cambios se perderán.';tr = 'Veri değişti. Tüm değişiklikler kaybolacak.';it = 'I dati sono stati modificati. Tutte le modifiche andranno perse.';de = 'Daten geändert. Alle Änderungen gehen verloren.'");
			Return;
		EndIf;
		
		QuestionText = NStr("en = 'Contact information content was modified.
		                    |Save changes?'; 
		                    |ru = 'Состав контактной информации был изменен.
		                    |Сохранить изменения?';
		                    |pl = 'Zmieniono zawartość informacji kontaktowych.
		                    |Zapisać zmiany?';
		                    |es_ES = 'El contenido de la información de contacto se ha modificado.
		                    |¿Guardar los cambios?';
		                    |es_CO = 'El contenido de la información de contacto se ha modificado.
		                    |¿Guardar los cambios?';
		                    |tr = 'İletişim bilgileri değiştirildi.
		                    |Değişiklikler kaydedilsin mi?';
		                    |it = 'Il contenuto delle informazioni di contatto è stato modificato.
		                    |Salvare modifiche?';
		                    |de = 'Der Inhalt der Kontaktinformation wurde geändert.
		                    |Änderungen speichern?'");
		
		Notification = New NotifyDescription("BeforeCloseSaveOffered", ThisForm);
		ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNoCancel, , DialogReturnCode.Cancel, NStr("en = 'Edit contact information content'; ru = 'Редактирование состава контактной информации';pl = 'Edytuj zawartość informacji kontaktowych';es_ES = 'Editar el contenido de la información de contacto';es_CO = 'Editar el contenido de la información de contacto';tr = 'İletişim bilgileri düzenle';it = 'Modifica il contenuto delle informazioni di contatto';de = 'Inhalt der Kontaktinformation bearbeiten'"));
		
		Cancel = True;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

// Procedure - handler commands SaveAndClose.
//
&AtClient
Procedure SaveAndClose(Command)
	
	If Modified Then
		SaveSettings();
	EndIf;
	
	Close(PrintContentChanged);
	
EndProcedure

// Procedure - Cancel command handler.
//
&AtClient
Procedure Cancel(Command)
	
	Modified = False;
	Close(PrintContentChanged);
	
EndProcedure

#EndRegion

#Region FormAttributesEventsHandlers

// Procedure - events handler OnChange CounterpartyTIN attribute.
//
&AtClient
Procedure CounterpartyTINOnChange(Item)
	
	SetModifiedFlag();
	
EndProcedure

// Procedure - events  handler OnChange MainContactPerson attribute.
//
&AtClient
Procedure MainContactPersonOnChange(Item)
	
	SetModifiedFlag();
	
EndProcedure

// Procedure - events  handler OnChange OtherContactPersons attribute.
//
&AtClient
Procedure OtherContactPersonsOnChange(Item)
	
	SetModifiedFlag();
	
EndProcedure

// Procedure - events  handler OnChange ResponsibleManager attribute.
//
&AtClient
Procedure ResponsibleManagerOnChange(Item)
	
	SetModifiedFlag();
	
EndProcedure

// Procedure - assigned OnChange events handler of added attributes of contact information kinds.
//
&AtClient
Procedure Attachable_AddedCIKind_OnChange(Item)
	
	If Item.Parent = Items.ContactInformationContactPersons Then
		If ThisForm[Item.Name] = True AND MainContactPerson = False AND OtherContactPersons = False Then
			MainContactPerson = True;
		EndIf;
	ElsIf Item.Parent = Items.ContactInformationResponsibleManager Then
		If ThisForm[Item.Name] = True AND ResponsibleManager = False Then
			ResponsibleManager = True;
		EndIf;
	EndIf;
	
	SetModifiedFlag();

EndProcedure

#EndRegion

#Region CommonProceduresAndFunctions

&AtServer
Procedure SaveSettings()
	
	UsedCIKinds = New Map;
	
	For Each KeyAndValue In StructureOfCIAttributesAndKinds Do

		UsedCIKinds.Insert(KeyAndValue.Value, ThisForm[KeyAndValue.Key]);
			
	EndDo;
	
	Common.CommonSettingsStorageSave("ManagementStructureTheContactInformationOfTheCounterparty",
		"UsedCIKinds", UsedCIKinds);
	Common.CommonSettingsStorageSave("ManagementStructureTheContactInformationOfTheCounterparty",
		"CounterpartyTIN", CounterpartyTIN);
	Common.CommonSettingsStorageSave("ManagementStructureTheContactInformationOfTheCounterparty",
		"MainContactPerson", MainContactPerson);
	Common.CommonSettingsStorageSave("ManagementStructureTheContactInformationOfTheCounterparty",
		"OtherContactPersons", OtherContactPersons);
	Common.CommonSettingsStorageSave("ManagementStructureTheContactInformationOfTheCounterparty",
		"ResponsibleManager", ResponsibleManager);
		
	Modified = False;
	PrintContentChanged = True;
		
EndProcedure

&AtServer
Procedure LoadSettings()
	
	UsedCIKinds = Common.CommonSettingsStorageLoad("ManagementStructureTheContactInformationOfTheCounterparty",
		"UsedCIKinds", New Map);
		
	CounterpartyTIN = Common.CommonSettingsStorageLoad("ManagementStructureTheContactInformationOfTheCounterparty",
		"CounterpartyTIN", True);
		
	MainContactPerson = Common.CommonSettingsStorageLoad("ManagementStructureTheContactInformationOfTheCounterparty",
		"MainContactPerson", True);
		
	OtherContactPersons = Common.CommonSettingsStorageLoad("ManagementStructureTheContactInformationOfTheCounterparty",
		"OtherContactPersons", True);
		
	ResponsibleManager = Common.CommonSettingsStorageLoad("ManagementStructureTheContactInformationOfTheCounterparty",
		"ResponsibleManager", True);
		
		
	For Each KeyAndValue In StructureOfCIAttributesAndKinds Do
			
		UseKEY = UsedCIKinds.Get(KeyAndValue.Value);

		// If there is no available kind of contact information in saved user settings, then we set usage by default
		If UseKEY = Undefined Then
			ThisForm[KeyAndValue.Key] = DriveServer.SetPrintDefaultCIKind(KeyAndValue.Value);
		Else
			ThisForm[KeyAndValue.Key] = UseKEY;
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure BeforeCloseSaveOffered(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		SaveSettings();
		Close(PrintContentChanged);
	ElsIf QuestionResult = DialogReturnCode.No Then
		Modified = False;
		Close(PrintContentChanged);
	EndIf;
	
EndProcedure

&AtServer
Procedure AddContactInformationAttributes()
	
	TypeDescriptionBoolean = New TypeDescription("Boolean");
	AttributesToAdd = New Array;
	
	Selection = DriveServer.GetAvailableForPrintingCIKinds().Select();
	
	RecNo = 0;
	While Selection.Next() Do
		
		RecNo = RecNo + 1;
		
		AttributeName = "AddedCIKind_" + RecNo;
		AttributesToAdd.Add(New FormAttribute(AttributeName, TypeDescriptionBoolean, , Selection.Description));
		StructureOfCIAttributesAndKinds.Insert(AttributeName, Selection.CIKind);
		
	EndDo;
	
	ChangeAttributes(AttributesToAdd);
	
	RecNo = 0;
	Selection.Reset();
	
	While Selection.Next() Do
		
		RecNo = RecNo + 1;
		
		If Selection.CIOwnerIndex = 1 Then
			
			GroupNumber = ?(RecNo % 3 = 0, 3, RecNo % 3);
			Parent = Items["ContactInformationCounterparty" + GroupNumber];
			
		ElsIf Selection.CIOwnerIndex = 2 Then
			
			Parent = Items.ContactInformationContactPersons;

		ElsIf Selection.CIOwnerIndex = 3 Then
			
			Parent = Items.ContactInformationResponsibleManager;
			
		EndIf;
		
		ItemName = "AddedCIKind_" + RecNo;
		AddItemFormsCheckBoxControl(ItemName, Parent);
		
	EndDo;
	
EndProcedure

&AtServer
Function AddItemFormsCheckBoxControl(ItemName, Parent = Undefined, DataPath = "")
	
	If IsBlankString(DataPath) Then 
		DataPath = ItemName;
	EndIf;
	
	FormItem = Items.Add(ItemName, Type("FormField"), Parent);
	FormItem.DataPath = DataPath;
	FormItem.Type = FormFieldType.CheckBoxField;
	FormItem.TitleLocation = FormItemTitleLocation.Right;
	FormItem.SetAction("OnChange", "Attachable_AddedCIKind_OnChange");
	
	Return FormItem;
	
EndFunction

&AtClient
Procedure SetModifiedFlag()
	
	Modified = True;
	
EndProcedure

#EndRegion