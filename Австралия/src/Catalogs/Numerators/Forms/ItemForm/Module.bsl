#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillServiceFields();
	FillIndependentNumbering();
	If Object.Ref = Catalogs.Numerators.Default Then
		Items.ValidForPage.Visible = False;
	Else
		ReadNumberingSettings();
	EndIf;
	Numbering.FillDocumentsTypesList(Items.NumberingSettingsDocumentType.ChoiceList);
	SetConditionalAppearance();
	GenerateNumberExample();
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	GenerateValidForTitle();
	GenerateIndependentNumberingTitle();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Modified And Not Exit Then
		Notification = New NotifyDescription("QuestionBeforeCloseCompletion", ThisObject);
		QuestionText = NStr("en = 'Data was changed. Do you want to save changes?'; ru = 'Данные были изменены. Сохранить изменения?';pl = 'Dane zostały zmienione. Czy chcesz zapisać zmiany?';es_ES = 'Datos se han cambiado. ¿Quiere guardar los cambios?';es_CO = 'Datos se han cambiado. ¿Quiere guardar los cambios?';tr = 'Veriler değiştirildi. Değişiklikleri kaydetmek istiyor musunuz?';it = 'I dati sono stati modificati. Salvare le modifiche?';de = 'Die Daten wurden geändert. Möchten Sie Änderungen speichern?'");
		ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNoCancel);
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	For Each String In IndependentNumbering Do
		Object[String.Value] = String.Check;
	EndDo;
	
	ErrorText = "";
	
	If Not NumberTagFound(Object.NumberFormat, ErrorText, Cancel) Then 
		If Not Cancel Then 
			ErrorText = NStr("en = 'Number format does not contain the Number service field'; ru = 'Формат числа не содержит служебное поле ""Номер""';pl = 'Format numeru nie zawiera pola serwisowego numeru';es_ES = 'El formato de número no contiene el Número de campo de servicio';es_CO = 'El formato de número no contiene el Número de campo de servicio';tr = 'Sayı biçimi, Sayı hizmeti alanını içermiyor';it = 'Il formato del numero non contiene il campo Servizio numero';de = 'Das Zahlenformat enthält nicht das Feld Nummer Service'");
		EndIf;
		CommonClientServer.MessageToUser(ErrorText, , "Object.NumberFormat", , Cancel);
		Return;
	EndIf;
	
	ObjectData = New Structure(
		"Ref,
		|NumberFormat,
		|Periodicity,
		|IndependentNumberingByDocumentTypes,
		|IndependentNumberingByOperationTypes,
		|IndependentNumberingByCompanies,
		|IndependentNumberingByBusinessUnits,
		|IndependentNumberingByCounterparties");
	FillPropertyValues(ObjectData, Object);
	
	If NumberingParametersChanged(ObjectData) Then 
		
		QuestionText = NStr("en = 'There are generated numbers for this numerator.
			|Are you sure you want to change the numbering parameters?'; 
			|ru = 'Для этого нумератора сгенерированы числа.
			|Вы хотите изменить параметры нумерации?';
			|pl = 'Istnieją wygenerowane numery dla tego licznika.
			|Czy na pewno chcesz zmienić parametry numeracji?';
			|es_ES = 'Para este numerador se generan números.
			|¿Está seguro de que desea cambiar los parámetros de numeración?';
			|es_CO = 'Para este numerador se generan números.
			|¿Está seguro de que desea cambiar los parámetros de numeración?';
			|tr = 'Bu sayaç için üretilen sayılar vardır. 
			|Numaralandırma parametrelerini değiştirmek istediğinize emin misiniz?';
			|it = 'Ci sono numeri generati per questo numeratore.
			|Siete sicuri di voler modificare i parametri di numerazione?';
			|de = 'Für diesen Zähler gibt es generierte Nummern.
			|Sind Sie sicher, dass Sie die Parameter der Nummerierung ändern möchten?'");
		If Not WriteParameters.Property("WriteComfirmationShown") Then
			NotifyDescription = New NotifyDescription(
				"BeforeWriteFollowUpAfterWriteConfirmation",
				ThisObject,
				WriteParameters);
			ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.No);
			Cancel = True;
			Return;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	WriteNumberingSettings(CurrentObject.Ref);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	If WriteParameters.Property("Close") Then
		Close();
	EndIf;
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	For Each Row In NumberingSettings Do
		If Not ValueIsFilled(Row.DocumentType) Then 
			RowNumber = NumberingSettings.IndexOf(Row);
			CommonClientServer.MessageToUser(
				NStr("en = '""Document type"" is not specified'; ru = 'Поле ""Тип документа"" не заполнено';pl = '""Rodzaj dokumentu"" nie jest określony';es_ES = '""Tipo de documento"" no está especificado.';es_CO = '""Tipo de documento"" no está especificado.';tr = '""Belge türü"" belirtilmedi';it = '""Il tipo documento"" non è specificato';de = '""Dokumenttyp"" ist nicht angegeben'"),
				,
				"NumberingSettings[" + Format(RowNumber, "NZ=; NG=") + "].DocumentType",
				,
				Cancel);
		EndIf;
	EndDo;
	
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
Procedure NumericNumberPartLengthOnChange(Item)
	
	GenerateNumberExample();
	
EndProcedure

&AtClient
Procedure NumberFormatOnChange(Item)
	
	GenerateNumberExample();
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersServiceFields

&AtClient
Procedure ServiceFieldsChoice(Item, RowSelected, Field, StandardProcessing)
	
	MoveServiceField();
	
EndProcedure

&AtClient
Procedure ServiceFieldsDragStart(Item, DragParameters, Perform)
	
	If ValueIsFilled(Item.CurrentData.Value) Then
		DragParameters.Value = Item.CurrentData.Value;
	Else
		Perform = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersNumberingSettings

&AtClient
Procedure NumberingSettingsOnEditEnd(Item, NewRow, CancelEdit)
	
	If NewRow Then 
		GenerateValidForTitle();
	EndIf;
	
EndProcedure

&AtClient
Procedure NumberingSettingsAfterDelete(Item)
	
	GenerateValidForTitle();
	
EndProcedure

&AtClient
Procedure NumberingSettingsDocumentTypeOnChange(Item)
	
	CurrentData = Items.NumberingSettings.CurrentData;
	
	If ValueIsFilled(CurrentData.DocumentType) Then
		
		NumberingSettingsDocumentTypeOnChangeAtServer(Items.NumberingSettings.CurrentRow);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersIndependentNumbering

&AtClient
Procedure IndependentNumberingMarkOnChange(Item)
	
	GenerateIndependentNumberingTitle();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure AddServiceField(Command)
	
	MoveServiceField();
	
EndProcedure

&AtClient
Procedure WriteAndCloseCommand(Command)
	
	WriteAndClose();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillServiceFields()
	
	ServiceFields.Clear();
	
	DefLangCode = CommonClientServer.DefaultLanguageCode();
	
	ServiceFields.Add(NStr("en = '[Number]'; ru = '[Number]';pl = '[Number]';es_ES = '[Number]';es_CO = '[Number]';tr = '[Number]';it = '[Number]';de = '[Number]'",	DefLangCode),	NStr("en = 'Number'; ru = 'Номер';pl = 'Numer';es_ES = 'Número';es_CO = 'Número';tr = 'Numara';it = 'Numero';de = 'Nummer'"));
	ServiceFields.Add(NStr("en = '[Day]'; ru = '[Day]';pl = '[Day]';es_ES = '[Day]';es_CO = '[Day]';tr = '[Day]';it = '[Day]';de = '[Day]'",		DefLangCode),	NStr("en = 'Day'; ru = 'День';pl = 'Dzień';es_ES = 'Día';es_CO = 'Día';tr = 'Gün';it = 'Giorno';de = 'Tag'"));
	ServiceFields.Add(NStr("en = '[Month]'; ru = '[Month]';pl = '[Month]';es_ES = '[Month]';es_CO = '[Month]';tr = '[Month]';it = '[Month]';de = '[Month]'",	DefLangCode),	NStr("en = 'Month number'; ru = 'Номер месяца';pl = 'Numer miesiąca';es_ES = 'Número del mes';es_CO = 'Número del mes';tr = 'Ay numarası';it = 'Mese numero';de = 'Monatsnummer'"));
	ServiceFields.Add(NStr("en = '[Quarter]'; ru = '[Quarter]';pl = '[Quarter]';es_ES = '[Quarter]';es_CO = '[Quarter]';tr = '[Quarter]';it = '[Quarter]';de = '[Quarter]'",	DefLangCode),	NStr("en = 'Quarter number'; ru = 'Номер квартала';pl = 'Numer kwartału';es_ES = 'Número del trimestre';es_CO = 'Número del trimestre';tr = 'Çeyrek yıl numarası';it = 'Trimestre numero';de = 'Quartalsnummer'"));
	ServiceFields.Add(NStr("en = '[Year2]'; ru = '[Year2]';pl = '[Year2]';es_ES = '[Year2]';es_CO = '[Year2]';tr = '[Year2]';it = '[Year2]';de = '[Year2]'",	DefLangCode),	NStr("en = 'Year (2 characters)'; ru = 'Год (2 символа)';pl = 'Rok (2 znaki)';es_ES = 'Año (2 caracteres)';es_CO = 'Año (2 caracteres)';tr = 'Yıl (iki karakter)';it = 'Anno (2 cifre)';de = 'Jahr (2 Zeichen)'"));
	ServiceFields.Add(NStr("en = '[Year4]'; ru = '[Year4]';pl = '[Year4]';es_ES = '[Year4]';es_CO = '[Year4]';tr = '[Year4]';it = '[Year4]';de = '[Year4]'",	DefLangCode),	NStr("en = 'Year (4 characters)'; ru = 'Год (4 символа)';pl = 'Rok (4 znaki)';es_ES = 'Año (4 caracteres)';es_CO = 'Año (4 caracteres)';tr = 'Yıl (4 karakter)';it = 'Anno (4 cifre)';de = 'Jahr (4 Zeichen)'"));
	
	ServiceFields.Add(NStr("en = '[InfobasePrefix]'; ru = '[InfobasePrefix]';pl = '[InfobasePrefix]';es_ES = '[InfobasePrefix]';es_CO = '[InfobasePrefix]';tr = '[InfobasePrefix]';it = '[InfobasePrefix]';de = '[InfobasePrefix]'",		DefLangCode), NStr("en = 'Infobase prefix'; ru = 'Префикс ИБ';pl = 'Prefiks bazy informacyjnej';es_ES = 'Prefijo de la infobase';es_CO = 'Prefijo de la infobase';tr = 'Infobase öneki';it = 'Prefisso Infobase';de = 'Präfix der Infobase'"));
	ServiceFields.Add(NStr("en = '[CompanyPrefix]'; ru = '[CompanyPrefix]';pl = '[CompanyPrefix]';es_ES = '[CompanyPrefix]';es_CO = '[CompanyPrefix]';tr = '[CompanyPrefix]';it = '[CompanyPrefix]';de = '[CompanyPrefix]'",		DefLangCode), NStr("en = 'Company prefix'; ru = 'Префикс организации';pl = 'Prefiks jednostki organizacyjnej';es_ES = 'Prefijo de la empresa';es_CO = 'Prefijo de la empresa';tr = 'İş yeri öneki';it = 'Prefisso Aziendale';de = 'Firmenpräfix'"));
	ServiceFields.Add(NStr("en = '[BusinessUnitPrefix]'; ru = '[BusinessUnitPrefix]';pl = '[BusinessUnitPrefix]';es_ES = '[BusinessUnitPrefix]';es_CO = '[BusinessUnitPrefix]';tr = '[BusinessUnitPrefix]';it = '[BusinessUnitPrefix]';de = '[BusinessUnitPrefix]'",	DefLangCode), NStr("en = 'Business unit prefix'; ru = 'Префикс структурной единицы';pl = 'Prefiks jednostki biznesowej';es_ES = 'Prefijo de la unidad empresarial';es_CO = 'Prefijo de la unidad empresarial';tr = 'Departman öneki';it = 'Prefisso Unità Aziendale';de = 'Abteilung-Präfix'"));
	ServiceFields.Add(NStr("en = '[CounterpartyPrefix]'; ru = '[CounterpartyPrefix]';pl = '[CounterpartyPrefix]';es_ES = '[CounterpartyPrefix]';es_CO = '[CounterpartyPrefix]';tr = '[CounterpartyPrefix]';it = '[CounterpartyPrefix]';de = '[CounterpartyPrefix]'",	DefLangCode), NStr("en = 'Counterparty prefix'; ru = 'Префикс контрагента';pl = 'Prefiks kontrahenta';es_ES = 'Prefijo de la contrapartida';es_CO = 'Prefijo de la contrapartida';tr = 'Cari hesap öneki';it = 'Prefisso controparte';de = 'Geschäftspartner-Präfix'"));
	ServiceFields.Add(NStr("en = '[OperationTypePrefix]'; ru = '[OperationTypePrefix]';pl = '[OperationTypePrefix]';es_ES = '[OperationTypePrefix]';es_CO = '[OperationTypePrefix]';tr = '[OperationTypePrefix]';it = '[OperationTypePrefix]';de = '[OperationTypePrefix]'",	DefLangCode), NStr("en = 'Operation type prefix'; ru = 'Префикс типа операции';pl = 'Prefiks rodzaju operacji';es_ES = 'Prefijo del tipo de operación';es_CO = 'Prefijo del tipo de operación';tr = 'İşlem türü öneki';it = 'Prefisso tipo operazione';de = 'Vorwahl des Operationstyps'"));
	
EndProcedure

&AtServer
Procedure FillIndependentNumbering()
	
	IndependentNumbering.Clear();
	
	IndependentNumbering.Add("IndependentNumberingByDocumentTypes",	 NStr("en = 'Document type'; ru = 'Тип документа';pl = 'Typ dokumentu';es_ES = 'Tipo de documento';es_CO = 'Tipo de documento';tr = 'Belge türü';it = 'Tipo di documento';de = 'Dokumententyp'"));
	IndependentNumbering.Add("IndependentNumberingByCompanies",		 NStr("en = 'Company'; ru = 'Организация';pl = 'Firma';es_ES = 'Empresa';es_CO = 'Empresa';tr = 'İş yeri';it = 'Azienda';de = 'Firma'"));
	IndependentNumbering.Add("IndependentNumberingByBusinessUnits",	 NStr("en = 'Business unit'; ru = 'Подразделение';pl = 'Jednostka biznesowa';es_ES = 'Unidad empresarial';es_CO = 'Unidad de negocio';tr = 'Departman';it = 'Unità aziendale';de = 'Abteilung'"));
	IndependentNumbering.Add("IndependentNumberingByCounterparties", NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'"));
	IndependentNumbering.Add("IndependentNumberingByOperationTypes", NStr("en = 'Operation type'; ru = 'Тип операции';pl = 'Typ operacji';es_ES = 'Tipo de operación';es_CO = 'Tipo de operación';tr = 'İşlem türü';it = 'Tipo di operazione';de = 'Operationstyp'"));
	
	For Each String In IndependentNumbering Do
		String.Check = Object[String.Value];
	EndDo;
	
EndProcedure

&AtServer
Procedure ReadNumberingSettings()
	
	If Object.Ref.IsEmpty() Then 
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	NumberingSettings.DocumentType AS DocumentType,
	|	NumberingSettings.OperationType AS OperationType,
	|	NumberingSettings.Company AS Company,
	|	NumberingSettings.BusinessUnit AS BusinessUnit,
	|	NumberingSettings.Counterparty AS Counterparty
	|FROM
	|	InformationRegister.NumberingSettings AS NumberingSettings
	|WHERE
	|	NumberingSettings.Numerator = &Numerator";
	Query.SetParameter("Numerator", Object.Ref);
	
	ValueToFormAttribute(Query.Execute().Unload(), "NumberingSettings");
	
	For Each Row In NumberingSettings Do
		SetOperationTypeType(Row);
	EndDo;
	
EndProcedure

&AtServer
Procedure SetOperationTypeType(CurrentData)
	
	OperationTypeTypeDescription = Numbering.GetOperationTypeTypeDescription(CurrentData.DocumentType);
	
	If OperationTypeTypeDescription = Undefined Then
		CurrentData.OperationType = Undefined;
	Else
		CurrentData.OperationType = OperationTypeTypeDescription.AdjustValue(CurrentData.OperationType);
	EndIf;
	
EndProcedure

&AtServer
Procedure NumberingSettingsDocumentTypeOnChangeAtServer(CurrentRow)
	
	CurrentData = NumberingSettings.FindByID(CurrentRow);
	SetOperationTypeType(CurrentData);
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	TextAll = TextAll();
	
	Fields = New Array;
	Fields.Add("OperationType");
	Fields.Add("Company");
	Fields.Add("BusinessUnit");
	Fields.Add("Counterparty");
	
	For Each Field In Fields Do
		
		Item = ConditionalAppearance.Items.Add();
		
		Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleDataColor);
		Item.Appearance.SetParameterValue("Text", TextAll);
		
		FilterItem = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
		FilterItem.LeftValue = New DataCompositionField("NumberingSettings." + Field);
		FilterItem.ComparisonType = DataCompositionComparisonType.NotFilled;
		
		FieldsItem = Item.Fields.Items.Add();
		FieldsItem.Field = New DataCompositionField("NumberingSettings" + Field);
		
	EndDo;
	
	If Object.Ref = Catalogs.Numerators.Default Then
		
		Item = ConditionalAppearance.Items.Add();
		
		Item.Appearance.SetParameterValue("ReadOnly", True);
		
		FilterItem = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
		FilterItem.LeftValue = New DataCompositionField("IndependentNumbering.Presentation");
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		ValueListItem = IndependentNumbering.FindByValue("IndependentNumberingByDocumentTypes");
		FilterItem.RightValue = ValueListItem.Presentation;
		
		FieldsItem = Item.Fields.Items.Add();
		FieldsItem.Field = New DataCompositionField("IndependentNumbering");
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function TextAll()
	
	Return NStr("en = '<all>'; ru = '<все>';pl = '<wszystkie>';es_ES = '<todo>';es_CO = '<all>';tr = '<tümü>';it = '<tutto>';de = '<alle>'");
	
EndFunction

&AtServer
Procedure GenerateNumberExample()
	
	ErrorDescription = "";
	ExampleGenerated = Numbering.GenerateNumberExample(
		Object.NumberFormat, Object.NumericNumberPartLength, Example, ErrorDescription);
	If Not ExampleGenerated Then 
		Example = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Number format error: %1'; ru = 'Ошибка формата числа: %1';pl = 'Błąd formatu numeru: %1';es_ES = 'Número del error de formato: %1';es_CO = 'Número del error de formato: %1';tr = 'Sayı biçimi hatası: %1';it = 'Numero errore formato: %1';de = 'Zahlenformat-Fehler: %1'"), ErrorDescription);
	EndIf;
	
	If Object.Example <> Example Then 
		Object.Example = Example;
	EndIf;
	
	Example = NStr("en = 'Example:'; ru = 'Пример:';pl = 'Przykład:';es_ES = 'Ejemplo:';es_CO = 'Ejemplo:';tr = 'Örnek:';it = 'Esempio:';de = 'Beispiel:'") + " " + Example;
	
EndProcedure

&AtClient
Procedure GenerateValidForTitle()
	
	NumberingSettingsCount = NumberingSettings.Count();
	
EndProcedure

&AtClient
Procedure GenerateIndependentNumberingTitle()
	
	IndependentNumberingMarksCount = 0;
	
	For Each String In IndependentNumbering Do
		If String.Check Then 
			IndependentNumberingMarksCount = IndependentNumberingMarksCount + 1
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure QuestionBeforeCloseCompletion(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		WriteAndClose();
	Else
		Modified = False;
		Close();
	EndIf;
	
EndProcedure

&AtServerNoContext
Function NumberTagFound(NumberFormat, ErrorText, Cancel)
	
	NumberFormatStructure = Undefined;
	ErrorDescription = "";
	
	If Not Numbering.ParseNumberFormat(NumberFormat, ErrorDescription, NumberFormatStructure) Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Number format error: %1'; ru = 'Ошибка формата числа: %1';pl = 'Błąd formatu numeru: %1';es_ES = 'Número del error de formato: %1';es_CO = 'Número del error de formato: %1';tr = 'Sayı biçimi hatası: %1';it = 'Numero errore formato: %1';de = 'Zahlenformat-Fehler: %1'"), ErrorDescription);
		Cancel = True;
		Return False;
	EndIf;
	
	NumberTagFound = False;
	For Each String In NumberFormatStructure Do
		If String.Key = "ServiceField" And String.Value = "Number" Then 
			NumberTagFound = True;
			Break;
		EndIf;
	EndDo;
	
	Return NumberTagFound;
	
EndFunction

&AtServerNoContext
Function NumberingParametersChanged(ObjectData)
	
	ObjectRefData = Numbering.GetNumeratorAttributes(ObjectData.Ref);
	
	RecordSet = InformationRegisters.Numbering.CreateRecordSet();
	RecordSet.Filter.Numerator.Set(ObjectData.Ref);
	RecordSet.Read();
	
	NumberingParametersChanged = ValueIsFilled(ObjectData.Ref) 
		And (ObjectData.NumberFormat <> ObjectRefData.NumberFormat 
			Or ObjectData.Periodicity <> ObjectRefData.Periodicity
			Or ObjectData.IndependentNumberingByDocumentTypes <> ObjectRefData.IndependentNumberingByDocumentTypes
			Or ObjectData.IndependentNumberingByOperationTypes <> ObjectRefData.IndependentNumberingByOperationTypes
			Or ObjectData.IndependentNumberingByCompanies <> ObjectRefData.IndependentNumberingByCompanies
			Or ObjectData.IndependentNumberingByBusinessUnits <> ObjectRefData.IndependentNumberingByBusinessUnits
			Or ObjectData.IndependentNumberingByCounterparties <> ObjectRefData.IndependentNumberingByCounterparties)
		And RecordSet.Count() > 0;
	
	Return NumberingParametersChanged;
	
EndFunction

&AtClient
Procedure BeforeWriteFollowUpAfterWriteConfirmation(Result, WriteParameters) Export
	
	If Result <> DialogReturnCode.Yes Then 
		Return;
	EndIf;
	WriteParameters.Insert("WriteComfirmationShown", True);
	Write(WriteParameters);
	
EndProcedure

&AtServer
Procedure WriteNumberingSettings(Ref)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	NumberingSettings.DocumentType,
	|	NumberingSettings.OperationType,
	|	NumberingSettings.Company,
	|	NumberingSettings.BusinessUnit,
	|	NumberingSettings.Counterparty
	|FROM
	|	InformationRegister.NumberingSettings AS NumberingSettings
	|WHERE
	|	NumberingSettings.Numerator = &Numerator";
	Query.SetParameter("Numerator", Ref);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		RecordManager = InformationRegisters.NumberingSettings.CreateRecordManager();
		FillPropertyValues(RecordManager, Selection);
		RecordManager.Delete();
	EndDo;
	
	For Each String In NumberingSettings Do
		RecordManager = InformationRegisters.NumberingSettings.CreateRecordManager();
		FillPropertyValues(RecordManager, String);
		If Not ValueIsFilled(String.OperationType) Then
			RecordManager.OperationType = Undefined;
		EndIf;
		RecordManager.Numerator = Ref;
		RecordManager.Write();
	EndDo;
	
EndProcedure

&AtClient
Procedure MoveServiceField()
	
	If Not ReadOnly Then 
		CurrentRow = Items.ServiceFields.CurrentRow;
		FieldValue = ServiceFields.Get(CurrentRow).Value;
		Object.NumberFormat  = Object.NumberFormat + FieldValue;
		GenerateNumberExample();
		Modified = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure WriteAndClose()
	
	WriteParameters = New Structure();
	WriteParameters.Insert("Close", True);
	Write(WriteParameters);
	
EndProcedure

#EndRegion