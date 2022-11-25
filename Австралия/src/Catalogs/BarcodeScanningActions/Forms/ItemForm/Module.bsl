
#Region FormEventHandlers

&AtClient
Procedure OnOpen(Cancel)
	DocumentType = DocumentTypeSynonim(Object.DocumentType);
	FormManagement();
	DriveClientServer.SetListFilterItem(BarcodeScanningEvents, "Action", Object.Ref);
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	DriveClientServer.SetListFilterItem(BarcodeScanningEvents, "Action", Object.Ref);
	FormManagement();
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DocumentTypeStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	NotifyDescription = New NotifyDescription("ChangingDocumentTypeSelectionMade", ThisObject);
	FormParameters = New Structure;
	FormParameters.Insert("CurrentObject", Object.DocumentType);
	OpenForm("Catalog.BarcodeScanningActions.Form.DocumentTypeSelection", FormParameters, , , , , NotifyDescription);

EndProcedure

&AtClient
Procedure ActionOnChange(Item)
	FormManagement();
	FillChangingAttributesTable();
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region ChangingAttributesFormTableItemsEventHandlers

&AtClient
Procedure ChangingAttributesBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	Cancel = True;
EndProcedure

&AtClient
Procedure ChangingAttributesBeforeDeleteRow(Item, Cancel)
	Cancel = True;
EndProcedure

&AtClient
Procedure ChangingAttributesBeforeRowChange(Item, Cancel)
	If Item.CurrentItem.Name = "ChangingAttributesValue" Then
		Item.CurrentItem.TypeRestriction = ItemTypeRestriction(Object.DocumentType, Item.CurrentData.Attribute, Item.CurrentData.OperationKind);
	EndIf;
EndProcedure

&AtClient
Procedure ChangingAttributesValueOnChange(Item)
	CurrentData = Item.Parent.CurrentData;
	CurrentData.Change = ValueIsFilled(CurrentData.Value);
EndProcedure

&AtClient
Procedure ChangingAttributesChangeOnChange(Item)
	CurrentData = Item.Parent.CurrentData;
	CurrentData.Value = ?(CurrentData.Change, CurrentData.Value, Undefined);
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure CreateBarcodeScanningEvent(Command)
	If Object.Ref.IsEmpty() Then
		ShowMessageBox(, NStr("en = 'You cannot assign the action until the data is saved.'; ru = 'Необходимо сохранить данные для того, чтобы назначить действие.';pl = 'Nie możesz przypisać akcji, dopóki dane nie zostaną zapisane.';es_ES = 'No puede asignar la acción hasta que se guarden los datos.';es_CO = 'No puede asignar la acción hasta que se guarden los datos.';tr = 'Veriler kaydedilmeden eylemi atayamazsınız.';it = 'Impossibile assegnare l''azione prima del salvataggio dei dati.';de = 'Sie können die Aktion erst dann zuordnen, wenn die Daten gesichert sind.'"));
	Else
		ActionFilter = New Structure;
		ActionFilter.Insert("Action", Object.Ref);
		ParametersStructure = New Structure;
		ParametersStructure.Insert("FillingValues", ActionFilter);
		OpenForm("InformationRegister.BarcodeScanningEvents.RecordForm", ParametersStructure);
	EndIf;
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ChangingDocumentTypeSelectionMade(SelectedObject, AdditionalParameters) Export
	If SelectedObject <> Undefined AND Object.DocumentType <> SelectedObject Then
		Object.DocumentType = SelectedObject;
		DocumentType = DocumentTypeSynonim(Object.DocumentType);
		FillChangingAttributesTable();
	EndIf;
EndProcedure

&AtServerNoContext
Function DocumentTypeSynonim(DocumentType) Export
	Return Common.ObjectAttributeValue(DocumentType, "Synonym");
EndFunction

&AtClient
Procedure FormManagement()
	Items.Attributes.Visible = Object.Action;
	Items.DocumentType.Enabled = Object.Ref.IsEmpty();
EndProcedure

&AtServer
Procedure FillChangingAttributesTable()
	
	Object.ChangingAttributes.Clear();
	If Object.Action And ValueIsFilled(Object.DocumentType) Then
		
		MetadataObject = Common.MetadataObjectByID(Object.DocumentType);
		ObjectEmptyRefValue = Common.ObjectAttributeValue(Object.DocumentType, "EmptyRefValue");
		
		For Each Attribute In MetadataObject.Attributes Do
			NewLine					= Object.ChangingAttributes.Add();
			NewLine.Attribute		= Attribute.Name;
			NewLine.Presentation	= ?(Attribute.Synonym="", Attribute.Name, Attribute.Synonym);
			NewLine.OperationKind	= 1;
		EndDo;
		
		Object.ChangingAttributes.Sort("Presentation");
		
		MetadataObjectName = MetadataObject.Name;
		MetadataObjectKind = Common.ObjectKindByRef(ObjectEmptyRefValue);
		ItemName = MetadataObjectKind + "_" + MetadataObjectName;
		AdditionalAttribute = Catalogs.AdditionalAttributesAndInfoSets.FindByDescription(ItemName);

		If Not AdditionalAttribute.IsEmpty() Then
		
			AdditionalAttributes = PropertyManager.ObjectProperties(ObjectEmptyRefValue, True, False);
			If ValueIsFilled(AdditionalAttributes) Then
				For Each Attribute In AdditionalAttributes Do
					NewLine					= Object.ChangingAttributes.Add();
					NewLine.Attribute		= Attribute.Description;
					NewLine.Presentation	= Attribute.Description;
					NewLine.OperationKind	= 2;
				EndDo;
			EndIf;
			
			AdditionalInformation = PropertyManager.ObjectProperties(ObjectEmptyRefValue, False, True);
			If ValueIsFilled(AdditionalInformation) Then
				For Each Attribute In AdditionalInformation Do
					NewLine					= Object.ChangingAttributes.Add();
					NewLine.Attribute		= Attribute.Description;
					NewLine.Presentation	= Attribute.Description;
					NewLine.OperationKind	= 3;
				EndDo;
			EndIf;
		
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function ItemTypeRestriction(DocumentType, Attribute, OperationKind)
	
	TypeRestriction = New TypeDescription("String");
	
	If OperationKind = 1 Then
		MetadataObject = Common.MetadataObjectByID(DocumentType);
		TypeRestriction = MetadataObject.Attributes[Attribute].Type;
	Else
		AdditionalAttribute = ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo.FindByDescription(Attribute);
		TypeRestriction = AdditionalAttribute.ValueType;
	EndIf;
	
	Return TypeRestriction;
	
EndFunction

#EndRegion