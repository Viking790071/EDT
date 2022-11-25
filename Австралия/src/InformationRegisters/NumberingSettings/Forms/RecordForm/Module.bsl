#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	IsNew = Parameters.Key.IsEmpty();
	
	If IsNew Then
		FillDimensionsTable();
	EndIf;
	
	StartRecord = New Structure("DocumentType, OperationType, Company, BusinessUnit, Counterparty");
	FillPropertyValues(StartRecord, Record);
	
	SetConditionalAppearance();
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	For Each String In DimensionTable Do
		If String.Name = "OperationType"
			And Not ValueIsFilled(String.Value) Then
			Record.OperationType = Undefined;
		Else
			Record[String.Name] = String.Value;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	FillDimensionsTable();
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If Not ValueIsFilled(Record.Numerator) Then
		CommonClientServer.MessageToUser(
			NStr("en = '""Numerator"" is not specified'; ru = 'Поле ""Нумератор"" не указано';pl = '""Licznik"" nie jest określony';es_ES = '""Numerador"" no está especificado';es_CO = '""Numerador"" no está especificado';tr = '""Sayıcı"" belirtilmemiş';it = '""Numeratore"" non speicficato';de = '""Zähler"" ist nicht angegeben'"), ,
			"Presentation", , Cancel);
	EndIf;
	
	If Record.Numerator = Catalogs.Numerators.Default Then
		CommonClientServer.MessageToUser(
			NStr("en = 'Specifying settings for ""Default"" numerator is not provided'; ru = 'Настройка нумератора ""по умолчанию"" не возможна';pl = 'Określone ustawienia dla ""Domyślnego"" licznika nie jest Specifying obsługiwane';es_ES = 'No se proporciona la especificación de las configuraciones para el numerador ""Por defecto""';es_CO = 'No se proporciona la especificación de las configuraciones para el numerador ""Por defecto""';tr = '""Varsayılan"" sayıcı için ayar belirtilmemiştir';it = 'Non è prevista la specifica delle impostazioni per il numeratore ""Predefinito""';de = 'Das Festlegen von Einstellungen für den Zähler ""Standard"" ist nicht vorgesehen'"), ,
			"Presentation", , Cancel);
	EndIf;
	
	If Not ValueIsFilled(Record.DocumentType) Then 
		CommonClientServer.MessageToUser(
			NStr("en = '""Document type"" is not specified'; ru = 'Поле ""Тип документа"" не заполнено';pl = '""Rodzaj dokumentu"" nie jest określony';es_ES = '""Tipo de documento"" no está especificado.';es_CO = '""Tipo de documento"" no está especificado.';tr = '""Belge türü"" belirtilmedi';it = '""Il tipo documento"" non è specificato';de = '""Dokumenttyp"" ist nicht angegeben'"), , "DimensionTable[0].Value", , Cancel);
	EndIf;
	
	DimensionsChanged = False;
	For Each Item In StartRecord Do
		If Item.Value <> Record[Item.Key] Then 
			DimensionsChanged = True;
		EndIf;
	EndDo;
	
	If IsNew Or DimensionsChanged Then 
		If HasDuplicate() Then 
			CommonClientServer.MessageToUser(
				NStr("en = 'Numbering setting is already defined for the specified ""Valid for"" fields'; ru = 'Для указанных полей ""Действительно до"" уже определены настройки нумерации';pl = 'Ustawienie numeracji jest już określone dla określonyh pól ""Ważny dla""';es_ES = 'La configuración de la numeración ya está definida para los campos especificados ""Válido para""';es_CO = 'La configuración de la numeración ya está definida para los campos especificados ""Válido para""';tr = 'Numaralandırma ayarı belirtilen ""Geçerli için geçerli"" alanları için önceden tanımlanmış';it = 'L''impostazione numerica è già definita per i campi ""Valido per""';de = 'Die Nummerierungseinstellung ist für die angegebenen ""Gültig für"" Felder bereits definiert'"), ,
				"DimensionTable", , Cancel);
			Return;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PresentationStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	NotifyDescription = New NotifyDescription("GeneratePresentationField", ThisObject);
	
	FormParameters =  New Structure;
	FormParameters.Insert("CurrentLine", Record.Numerator);
	
	OpenForm("Catalog.Numerators.ChoiceForm", FormParameters, ThisForm, , , ,
		NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersDimensionTable

&AtClient
Procedure DimensionTableValueStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentData = Items.DimensionTable.CurrentData;
	If CurrentData = Undefined Then 
		Return;
	EndIf;
	
	If CurrentData.Name = "DocumentType" Then 
		
		StandardProcessing = False;
		
		NotifyDescription = New NotifyDescription(
			"ValueStartChoiceFollowUp",
			ThisObject,
			New Structure("CurrentData", CurrentData));
		
		List = New ValueList;
		FillDocumentsTypesList(List);
		
		ShowChooseFromList(NotifyDescription, List, Item);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillDimensionsTable()
	
	DimensionTable.Clear();
	
	Dimensions = Metadata.InformationRegisters.NumberingSettings.Dimensions;
	For Each Dimension In Dimensions Do
		
		DimensionName = Dimension.Name;
		
		NewRow = DimensionTable.Add();
		NewRow.Name = DimensionName;
		NewRow.Presentation = ?(IsBlankString(Dimension.Synonym), DimensionName, Dimension.Synonym);
		NewRow.Type = Dimension.Type;
		NewRow.Value = Record[DimensionName];
		
	EndDo;
	
	SeOperationTypeType(Record.DocumentType);
	
	Presentation = GeneratePresentationFieldAtServer(Record.Numerator);
	
EndProcedure

&AtClient
Procedure GeneratePresentationField(SelectedValue, Parameters) Export 
	
	Record.Numerator = SelectedValue;
	Presentation = GeneratePresentationFieldAtServer(Record.Numerator);
	
EndProcedure

&AtServerNoContext
Function GeneratePresentationFieldAtServer(Numerator)
	
	Return Numbering.GeneratePresentationField(Numerator);
	
EndFunction

&AtServer
Procedure FillDocumentsTypesList(List)
	
	Numbering.FillDocumentsTypesList(List);
	
EndProcedure

&AtClient
Procedure ValueStartChoiceFollowUp(SelectedItem, Parameters) Export 
	
	If SelectedItem = Undefined Then 
		Return;
	EndIf;
	
	CurrentData = Parameters.CurrentData;
	CurrentData.Value = SelectedItem.Value;
	
	SeOperationTypeType(CurrentData.Value);
	
EndProcedure

&AtServer
Procedure SeOperationTypeType(DocumentType)
	
	OperationTypeTypeDescription = Numbering.GetOperationTypeTypeDescription(DocumentType);
	
	FoundRows = DimensionTable.FindRows(New Structure("Name", "OperationType"));
	If FoundRows.Count() > 0 Then 
		FoundRow = FoundRows[0];
		If OperationTypeTypeDescription = Undefined Then
			FoundRow.Value = Undefined;
		Else
			FoundRow.Value = OperationTypeTypeDescription.AdjustValue(FoundRow.Value);
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Function HasDuplicate() 
	
	SetPrivilegedMode(True);
	
	RecordManager = InformationRegisters.NumberingSettings.CreateRecordManager();
	FillPropertyValues(RecordManager, Record);
	
	RecordManager.Read();
	If RecordManager.Selected() Then 
		Return True;
	EndIf;
		
	Return False;
		
EndFunction

&AtServer
Procedure SetConditionalAppearance()
	
	TextAll = NStr("en = '<all>'; ru = '<все>';pl = '<wszystkie>';es_ES = '<todo>';es_CO = '<all>';tr = '<tümü>';it = '<tutto>';de = '<alle>'");
	
	Item = ConditionalAppearance.Items.Add();
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleDataColor);
	Item.Appearance.SetParameterValue("Text", TextAll);
	
	FilterItem = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("DimensionTable.Value");
	FilterItem.ComparisonType = DataCompositionComparisonType.NotFilled;
	
	FilterItem = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("DimensionTable.Name");
	FilterItem.ComparisonType = DataCompositionComparisonType.NotEqual;
	FilterItem.RightValue = "DocumentType";
	
	FieldsItem = Item.Fields.Items.Add();
	FieldsItem.Field = New DataCompositionField("DimensionTableValue");
	
	
	Item = ConditionalAppearance.Items.Add();
	
	Item.Appearance.SetParameterValue("MarkIncomplete", True);
	
	FilterItem = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("DimensionTable.Value");
	FilterItem.ComparisonType = DataCompositionComparisonType.NotFilled;
	
	FilterItem = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("DimensionTable.Name");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = "DocumentType";
	
	FieldsItem = Item.Fields.Items.Add();
	FieldsItem.Field = New DataCompositionField("DimensionTableValue");
	
EndProcedure

#EndRegion
