
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not Parameters.Property("DocRef") Then
		Cancel = True;
		Return;
	EndIf;
	
	If Parameters.Property("ThisIsReciept") Then
		ThisIsReciept = Parameters.ThisIsReciept;
	Else
		ThisIsReciept = False;
	EndIf;
	
	MessageText = "";
	If NOT Parameters.Property("Inventory") OR NOT ValueIsFilled(Parameters.Inventory.Products) Then
		MessageText = NStr("en = 'Products are not filled in.'; ru = 'Не заполнена номенклатура!';pl = 'Produkty nie są wprowadzone.';es_ES = 'Productos no se han rellenado.';es_CO = 'Productos no se han rellenado.';tr = 'Ürünler doldurulmadı.';it = 'Gli articoli non sono compilati.';de = 'Produkte sind nicht ausgefüllt.'");
	ElsIf NOT Parameters.Inventory.Products.UseSerialNumbers Then
		MessageText = NStr("en = 'The product is not serialized.'; ru = 'Для номенклатуры не ведется учет по серийным номерам.';pl = 'Produkt nie jest serializowany.';es_ES = 'El producto no está serialiazado.';es_CO = 'El producto no está serialiazado.';tr = 'Ürün serileştirilmemiş.';it = 'Il prodotto non è serializzato';de = 'Das Produkt wird nicht serialisiert.'");
	EndIf;
	
	If NOT IsBlankString(MessageText) Then
		CommonClientServer.MessageToUser(MessageText,,,,Cancel);
		Return;
	EndIf;
	OwnerFormUUID = Parameters.OwnerFormUUID;
	
	If Parameters.Property("PickMode") Then
		PickMode = Parameters.PickMode;
	Else
		Cancel = True;
	EndIf;
	
	If ValueIsFilled(Parameters.AddressInTemporaryStorage) Then
		
		SavedSerialNumbersValue = GetFromTempStorage(Parameters.AddressInTemporaryStorage);
		
		If TypeOf(SavedSerialNumbersValue) = Type("Structure") Then
			SerialNumbersOfCurrentString = SavedSerialNumbersValue.SerialNumbersOfCurrentString;
			SerialNumbersOfCurrentProduct = SavedSerialNumbersValue.SerialNumbersOfCurrentProduct;
		Else
			SerialNumbersOfCurrentString = SavedSerialNumbersValue;
			SerialNumbersOfCurrentProduct = Undefined;
		EndIf;
		
		If SerialNumbersOfCurrentProduct = Undefined Then
			SerialNumbersBalance.Parameters.SetParameterValue("CompleteListOfSelected", New Array);
		Else
			SerialNumbersBalance.Parameters.SetParameterValue("CompleteListOfSelected", SerialNumbersOfCurrentProduct.UnloadColumn("SerialNumber"));
		EndIf;
		
		If TypeOf(SerialNumbersOfCurrentString) = Type("CatalogRef.SerialNumbers") Then
			
			If ValueIsFilled(SerialNumbersOfCurrentString) Then
				NewRow = Object.SerialNumbers.Add();
				NewRow.SerialNumber = SerialNumbersOfCurrentString;
				NewRow.NewNumber = String(SerialNumbersOfCurrentString);
			EndIf;
			
		Else
			
			// If the document is used Marking Goods, then it has a special order of loading the series
			LoadSeriesSeparately = (SerialNumbersOfCurrentString.Columns.Find("Series")<>Undefined);
			
			For Each LoadingString In SerialNumbersOfCurrentString Do
				SerialNumbersString = Object.SerialNumbers.Add();
				FillPropertyValues(SerialNumbersString, LoadingString);
				
				If LoadSeriesSeparately Then
					SerialNumbersString.SerialNumber = LoadingString.Series;
				EndIf;
				
			EndDo;
			
			For Each Str In Object.SerialNumbers Do
				
				SerialNumberData = Common.ObjectAttributesValues(Str.SerialNumber, "Description" );
				FillPropertyValues(Str, SerialNumberData);
				Str.NewNumber = SerialNumberData.Description;
				
			EndDo;
			
		EndIf;
		
	EndIf;
	
	FillInventory(Parameters.Inventory);
	ListOfSelected.LoadValues(Object.SerialNumbers.Unload().UnloadColumn("SerialNumber"));
	
	If GetFunctionalOption("UseSerialNumbersAsInventoryRecordDetails") Then
		
		If Parameters.Property("DocSalesInvoice") Then
			HidePages = True;
			ThisDocument = Parameters.DocSalesInvoice;
			SerialNumbersBalance.QueryText = QueryTextSeriesBalancesByDocument();
		Else
			ThisDocument = Parameters.DocRef;
			SerialNumbersBalance.QueryText = QueryTextSeriesBalances();
		EndIf;
		
		If Parameters.Property("DocSalesInvoice") Then
			SetSerialNumberFromSalesInvoiceInListOfSelected(Parameters.DocRef, ThisDocument, ListOfSelected);
		EndIf;
		
		SerialNumbersBalance.Parameters.SetParameterValue("Products", Products);
		SerialNumbersBalance.Parameters.SetParameterValue("Company", Parameters.Company);
		SerialNumbersBalance.Parameters.SetParameterValue("Characteristic", Parameters.Inventory.Characteristic);
		
		If Parameters.Property("StructuralUnit") Then
			SerialNumbersBalance.Parameters.SetParameterValue("StructuralUnit",Parameters.StructuralUnit);
			SerialNumbersBalance.Parameters.SetParameterValue("AllWarehouses", False);
			If ValueIsFilled(Parameters.StructuralUnit) Then
				Items.SeriesBalancesSerie.Title = NStr("en = 'Available in'; ru = 'В наличии на';pl = 'Dostępne w';es_ES = 'Disponible en';es_CO = 'Disponible en';tr = 'De mevcut';it = 'Disponibile in';de = 'Verfügbar in'") + " " + Parameters.StructuralUnit;
			EndIf;
			ReferentialBatch = BatchesServer.ReferentialTrackingMethod(Products, Parameters.StructuralUnit);
		Else
			SerialNumbersBalance.Parameters.SetParameterValue("StructuralUnit", Undefined);
			SerialNumbersBalance.Parameters.SetParameterValue("AllWarehouses", True);
			ReferentialBatch = False;
		EndIf;
		
		If ReferentialBatch Then
			SerialNumbersBalance.Parameters.SetParameterValue("ReferentialBatch", True);
			SerialNumbersBalance.Parameters.SetParameterValue("Batch", Catalogs.ProductsBatches.EmptyRef());
		Else
			SerialNumbersBalance.Parameters.SetParameterValue("ReferentialBatch", False);
			SerialNumbersBalance.Parameters.SetParameterValue("Batch", Parameters.Inventory.Batch);
		EndIf;
		
		If Parameters.Property("Cell") Then
			SerialNumbersBalance.Parameters.SetParameterValue("Cell",Parameters.Cell);
			SerialNumbersBalance.Parameters.SetParameterValue("AllCells", False);
			
			If ValueIsFilled(Parameters.Cell) Then
				Items.SeriesBalancesSerie.Title = Items.SeriesBalancesSerie.Title + ", " + Parameters.Cell;
			EndIf;
		Else
			SerialNumbersBalance.Parameters.SetParameterValue("Cell", Undefined);
			SerialNumbersBalance.Parameters.SetParameterValue("AllCells", True);
		EndIf;
		
		SerialNumbersBalance.Parameters.SetParameterValue("ListOfSelected", ListOfSelected.UnloadValues());
		SerialNumbersBalance.Parameters.SetParameterValue("ThisDocument", ThisDocument);
		
		Items.ShowSold.Visible = False;
		Items.SeriesBalancesSold.Visible = ShowSold;
		
	Else // Without balance
		
		SerialNumbersBalance.QueryText = QueryTextSerialNumbers();
		SerialNumbersBalance.Parameters.SetParameterValue("Products",Products);
		SerialNumbersBalance.Parameters.SetParameterValue("ListOfSelected",ListOfSelected.UnloadValues());
		SerialNumbersBalance.Parameters.SetParameterValue("ShowSold", ShowSold);
		SerialNumbersBalance.Parameters.SetParameterValue("ThisDocument", Parameters.DocRef);
		
	EndIf;
	
	// SN template
	RestoreSettings();
	
	If NOT ValueIsFilled(Characteristic) Then
		Items.Characteristic.Visible = False;
	EndIf;
	If NOT ValueIsFilled(Batch) Then
		Items.Batch.Visible = False;
	EndIf;
	
	If PickMode Then
		Items.Pages.CurrentPage = Items.BalancesChoice;
	Else
		Items.Pages.CurrentPage = Items.AddingNew;
	EndIf;
	
	SetConditionalAppearance();
	
	Items.SerialNumbersUpdatePeriodAction.ChoiceList.Add(NStr("en = 'Generate sequentially'; ru = 'Формировать последовательно';pl = 'Wygeneruj po kolei';es_ES = 'Generar secuencialmente';es_CO = 'Generar secuencialmente';tr = 'Sıralı olarak oluştur';it = 'Genera in sequenza';de = 'Sequentiell generieren'"));
	Items.SerialNumbersUpdatePeriodAction.ChoiceList.Add(NStr("en = 'Generate range'; ru = 'Формировать диапазон';pl = 'Generowanie asortyment';es_ES = 'Generar rango';es_CO = 'Generar rango';tr = 'Aralık oluştur';it = 'Genera intervallo';de = 'Bereich generieren'"));
	
	SerialNumbersUpdatePeriodAction = Items.SerialNumbersUpdatePeriodAction.ChoiceList[0].Value;
	SerialNumbersRowsApdateCount = Max(CountInADocument - Object.SerialNumbers.Count(), 1);
	
	If GetCountDinamicList() = 0 And  Object.SerialNumbers.Count() = 0 And HidePages Then
		MessageText = NStr("en = 'There is no any serial number in Sales Invoice.'; ru = 'В инвойсе покупателю нет серийного номера.';pl = 'Nie ma numeru seryjnego w Fakturze sprzedaży.';es_ES = 'No hay ningún número de serie en la factura de venta.';es_CO = 'No hay ningún número de serie en la factura de venta.';tr = 'Satış faturasında seri numarası yok.';it = 'Non vi è numero di serie nella Fattura di vendita.';de = 'Es gibt keine Seriennummer in der Verkaufsrechnung.'");
		CommonClientServer.MessageToUser(MessageText);
		Cancel = True;
	EndIf;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If HidePages Then
		Items.AddingNew.Visible = False;
		Items.Pages.PagesRepresentation = FormPagesRepresentation.None;
	EndIf;
EndProcedure

&AtServer
Function GetCountDinamicList()
	
	Scheme = Items.SeriesBalances.GetPerformingDataCompositionScheme();
	Settings = Items.SeriesBalances.GetPerformingDataCompositionSettings();
	
	LayoutBuilder = New DataCompositionTemplateComposer();
	LayoutLayouts = LayoutBuilder.Execute(Scheme, Settings, , , Type("DataCompositionValueCollectionTemplateGenerator"));
	
	LayoutProcessor = New DataCompositionProcessor;
	LayoutProcessor.Initialize(LayoutLayouts);
	
	DataComposition = New DataCompositionResultValueCollectionOutputProcessor;
	
	ValueTable = New ValueTable;
	DataComposition.SetObject(ValueTable); 
	DataComposition.Output(LayoutProcessor);
	
	Return ValueTable.Count();
EndFunction

&AtServer
Procedure SetSerialNumberFromSalesInvoiceInListOfSelected(ThisDocument, DocSales, ListOfSelected)
	Query = New Query;
	Query.Text = WorkWithSerialNumbers.QueryTextSerialNumbersByDocument(ThisDocument);
	
	Query.SetParameter("Products", Products);
	Query.SetParameter("SalesDocument", DocSales);
	
	QueryResult = Query.Execute();
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		If Not ThisDocument = SelectionDetailRecords.Ref Then
			ListOfSelected.Add(SelectionDetailRecords.SerialNumber);
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Function QueryTextSeriesBalances()
	
	RequestText = "SELECT ALLOWED DISTINCT
	|	NestedSelect.SerialNumber AS SerialNumber
	|FROM
	|	(SELECT
	|		SerialNumbersBalance.SerialNumber AS SerialNumber
	|	FROM
	|		AccumulationRegister.SerialNumbers.Balance(
	|				,
	|				Company = &Company
	|					AND Products = &Products
	|					AND Characteristic = &Characteristic
	|					AND (&ReferentialBatch
	|						OR Batch = &Batch)
	|					AND (&AllWareHouses
	|						OR StructuralUnit = &StructuralUnit)
	|					AND (&AllCells
	|						OR Cell = &Cell)
	|					AND NOT SerialNumber IN (&ListOfSelected)
	|					AND NOT SerialNumber IN (&CompleteListOfSelected)) AS SerialNumbersBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		SerialNumbers.SerialNumber
	|	FROM
	|		AccumulationRegister.SerialNumbers AS SerialNumbers
	|	WHERE
	|		SerialNumbers.Recorder = &ThisDocument
	|		AND NOT SerialNumbers.SerialNumber IN (&ListOfSelected)
	|		AND NOT SerialNumbers.SerialNumber IN (&CompleteListOfSelected)
	|		AND SerialNumbers.Products = &Products
	|		AND SerialNumbers.Characteristic = &Characteristic
	|		AND (&ReferentialBatch
	|				OR SerialNumbers.Batch = &Batch)
	|		AND (&AllWareHouses
	|				OR SerialNumbers.StructuralUnit = &StructuralUnit)
	|		AND (&AllCells
	|				OR SerialNumbers.Cell = &Cell)) AS NestedSelect
	|
	|ORDER BY
	|	SerialNumber";
	
	Return RequestText;
	
EndFunction

&AtServer
Function QueryTextSeriesBalancesByDocument()
	
	RequestText = "SELECT ALLOWED DISTINCT
	|	NestedSelect.SerialNumber AS SerialNumber
	|FROM
	|	(SELECT
	|		SerialNumbers.SerialNumber AS SerialNumber
	|	FROM
	|		AccumulationRegister.SerialNumbers AS SerialNumbers
	|	WHERE
	|		SerialNumbers.Recorder = &ThisDocument
	|		AND NOT SerialNumbers.SerialNumber IN (&ListOfSelected)
	|		AND NOT SerialNumbers.SerialNumber IN (&CompleteListOfSelected)
	|		AND SerialNumbers.Products = &Products
	|		AND SerialNumbers.Characteristic = &Characteristic
	|		AND (&ReferentialBatch
	|				OR SerialNumbers.Batch = &Batch)
	|		AND (&AllWareHouses
	|				OR SerialNumbers.StructuralUnit = &StructuralUnit)
	|		AND (&AllCells
	|				OR SerialNumbers.Cell = &Cell)
	|		AND SerialNumbers.Company = &Company) AS NestedSelect";
	
	Return RequestText;
	
EndFunction

&AtServer
Function QueryTextSerialNumbers()
	
	RequestText = "SELECT DISTINCT
	|	NestedQuery.SerialNumber,
	|	NestedQuery.Sold
	|FROM
	|	(SELECT
	|		CatalogSerialNumbers.Ref AS SerialNumber,
	|		CatalogSerialNumbers.Sold AS Sold
	|	FROM
	|		Catalog.SerialNumbers AS CatalogSerialNumbers
	|	WHERE
	|		CatalogSerialNumbers.Owner = &Products
	|		AND NOT CatalogSerialNumbers.Ref IN (&ListOfSelected)
	|		AND CASE
	|			WHEN &ShowSold
	|				THEN TRUE
	|			ELSE NOT CatalogSerialNumbers.Sold
	|		END
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		SerialNumbers.SerialNumber,
	|		SerialNumbers.SerialNumber.Sold
	|	FROM
	|		AccumulationRegister.SerialNumbers AS SerialNumbers
	|	WHERE
	|		SerialNumbers.Recorder = &ThisDocument
	|		AND NOT SerialNumbers.SerialNumber IN (&ListOfSelected)
	|		AND SerialNumbers.SerialNumber.Owner = &Products) AS NestedQuery";
	
	Return RequestText;
	
EndFunction

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	//
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.SeriesSerie.Name);
	
	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("Object.SerialNumbers.SerialNumber");
	FilterElement.ComparisonType = DataCompositionComparisonType.NotFilled;
	Item.Appearance.SetParameterValue("Font", New Font(WindowsFonts.DefaultGUIFont, , , True, False, False, False, ));
	Item.Appearance.SetParameterValue("Text", NStr("en = 'New'; ru = 'Новая';pl = 'Nowy';es_ES = 'Nuevo';es_CO = 'Nuevo';tr = 'Yeni';it = 'Nuovo';de = 'Neu'"));
	
	//
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.SeriesSerie.Name);
	
	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("Object.SerialNumbers.SerialNumber");
	FilterElement.ComparisonType = DataCompositionComparisonType.Filled;
	Item.Appearance.SetParameterValue("Text", NStr("en = 'Existing'; ru = 'Существующие';pl = 'Istniejący';es_ES = 'Existente';es_CO = 'Existente';tr = 'Mevcut';it = 'Esistente';de = 'Bestehende'"));
	
EndProcedure

&AtServer
Function SaveSerialNumbersInput()
	
	VTSerialNumbers = Object.SerialNumbers.Unload();
	Object.SerialNumbers.Load(VTSerialNumbers);
	
	For Each TableStr In Object.SerialNumbers Do
		
		If Not ValueIsFilled(TableStr.SerialNumber) Then
			
			CatalogObject                = Catalogs.SerialNumbers.CreateItem();
			CatalogObject.Owner          = Products;
			CatalogObject.Description    = TableStr.NewNumber;
			
			FillPropertyValues(CatalogObject, TableStr);
			
			Try
				CatalogObject.Write();
			Except
				CommonClientServer.MessageToUser(ErrorDescription());
				Return False;
			EndTry;
			
			TableStr.SerialNumber = CatalogObject.Ref;
		EndIf;
		
	EndDo;
	
	AddressInTemporaryStorage = PutToTempStorage(Object.SerialNumbers.Unload());
	Modified = False;
	
	Return True;
	
EndFunction

&AtServer
Procedure FillInventory(Inventory)
	
	Products = Inventory.Products;
	Characteristic = Inventory.Characteristic;
	If Inventory.Property("Batch") Then
		Batch = Inventory.Batch;
	EndIf;
	If Inventory.Property("MeasurementUnit") Then
		MeasurementUnit = Inventory.MeasurementUnit;
		CountInADocument = Inventory.Quantity * Inventory.Ratio;
	Else
		CountInADocument = Inventory.Quantity;
	EndIf;
	
	If Inventory.Property("ConnectionKey") Then
		ConnectionKey = Inventory.ConnectionKey;
	EndIf;
	
EndProcedure

&AtClient
Procedure Complete(Command)
	
	SavedSuccess = SaveSerialNumbersInput();
	If SavedSuccess Then
		
		ReturnStructure = New Structure("RowKey, AddressInTemporaryStorage, ThisIsReciept", ConnectionKey, AddressInTemporaryStorage, ThisIsReciept);
		Notify("SerialNumbersSelection", ReturnStructure, 
			?(OwnerFormUUID = New UUID("00000000-0000-0000-0000-000000000000"), Undefined, OwnerFormUUID)
			);
		Close();
		
	EndIf; 
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	If NOT PickMode Then
		SaveSettings();
	EndIf;
	
EndProcedure

&AtServer
Procedure SaveSettings()
	
	SettingsString = "TemplateSerialNumber";
	SystemSettingsStorage.Save(FormName, FormName+"_TemplateSerialNumber", TemplateSerialNumber);
	
EndProcedure

&AtServer
Procedure RestoreSettings()
	
	SettingsString = "TemplateSerialNumber";
	TemplateSerialNumber = SystemSettingsStorage.Load(FormName, FormName+"_TemplateSerialNumber", TemplateSerialNumber);
	
	Items.SeriesNumber.Mask = WorkWithSerialNumbersClientServer.StringOfMaskByTemplate(TemplateSerialNumber);
	
EndProcedure

#EndRegion

#Region FormItemEventsHandlers

&AtServer
Function EvaluateMaximumNumberAndCount()
	
	MaximumNumberFromCatalog = Catalogs.SerialNumbers.CalculateMaximumSerialNumber(Products, TemplateSerialNumber);
	MaximumNumberInADocument = 0;
	For Each Str In Object.SerialNumbers Do
		
		If Not ValueIsFilled(Str.SerialNumber) And Str.SerialNumberNumeric=0 And ValueIsFilled(Str.NewNumber) Then
			TemplateSerialNumberAsString = ?(ValueIsFilled(TemplateSerialNumber),TemplateSerialNumber,"########");
			
			Str.SerialNumberNumeric = Catalogs.SerialNumbers.SerialNumberNumericByTemplate(Str.NewNumber, TemplateSerialNumberAsString);
			
		EndIf;
		
		MaximumNumberInADocument = Max(MaximumNumberInADocument, Str.SerialNumberNumeric);
	EndDo;
	
	Number = Max(MaximumNumberInADocument,MaximumNumberFromCatalog);
	
	Return Number;
	
EndFunction

&AtServer
Procedure GenerateSerialNumbersServer(CountGenerate, InitialNumber = Undefined)
	
	If InitialNumber = Undefined Then
		NextNumberByOrder = EvaluateMaximumNumberAndCount()+1;
	Else
		NextNumberByOrder = InitialNumber;
	EndIf;
	
	For nString=1 To CountGenerate Do
		NewNumberStructure = AddSerialNumberByTemplate(NextNumberByOrder);
		
		CurrentRow = Object.SerialNumbers.Add();
		CurrentRow.NewNumber = NewNumberStructure.NewNumber;
		CurrentRow.SerialNumberNumeric = NewNumberStructure.NewNumberNumeric;
		
		NextNumberByOrder = NextNumberByOrder+1;
	EndDo;
	
EndProcedure

&AtServer
Function AddSerialNumberServer()
	
	NextNumberByOrder = EvaluateMaximumNumberAndCount()+1;
	Return AddSerialNumberByTemplate(NextNumberByOrder);
	
EndFunction

&AtServer
Function AddSerialNumberByTemplate(CurrentMaximumNumber)
	
	NumberNumeric = CurrentMaximumNumber;
	
	If ValueIsFilled(TemplateSerialNumber) Then
		// Length of the digital part of the number - no more than 13 symbols
		DigitInTemplate = StrOccurrenceCount(TemplateSerialNumber, WorkWithSerialNumbersClientServer.CharNumber());
		CountOfCharactersSN = Max(DigitInTemplate, StrLen(NumberNumeric));
		NumberWithZeros = Format(NumberNumeric, "ND="+DigitInTemplate+"; NLZ=; NG=");
		
		NewNumberByTemplate = "";
		CharacterNumberSN = 1;
		// Filling the template
		For n=1 To StrLen(TemplateSerialNumber) Do
			Symb = Mid(TemplateSerialNumber,n,1);
			If Symb=WorkWithSerialNumbersClientServer.CharNumber() Then
				NewNumberByTemplate = NewNumberByTemplate+Mid(NumberWithZeros,CharacterNumberSN,1);
				CharacterNumberSN = CharacterNumberSN+1;
			Else
				NewNumberByTemplate = NewNumberByTemplate+Symb;
			EndIf;
		EndDo;
		NewNumber = NewNumberByTemplate;
	Else
		NewNumber = Format(NumberNumeric, "ND=8; NLZ=; NG=");
	EndIf;
	
	Return New Structure("NewNumber, NewNumberNumeric", NewNumber, NumberNumeric);
	
EndFunction

&AtClient
Procedure AddSerialNumber(Command)
	
	NewNumberStructure = AddSerialNumberServer();
	
	Items.SerialNumbersNew.AddRow();
	CurrentData = Items.SerialNumbersNew.CurrentData;
	CurrentData.NewNumber = NewNumberStructure.NewNumber;
	CurrentData.SerialNumberNumeric = NewNumberStructure.NewNumberNumeric;
	
	Items.SerialNumbersNew.EndEditRow(False);	
	
EndProcedure

&AtServer
Procedure FindRegistredSeries()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	SerialNumbers.SerialNumber AS SerialNumber,
	|	SerialNumbers.NewNumber AS NewNumber,
	|	CASE
	|		WHEN SerialNumbers.SerialNumber = """"
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS NumberNotSpecified,
	|	SerialNumbers.LineNumber AS LineNumber
	|INTO NewSerialNumbers
	|FROM
	|	&SerialNumbers AS SerialNumbers
	|WHERE
	|	SerialNumbers.SerialNumber = VALUE(Catalog.SerialNumbers.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SerialNumbers.Ref AS SerialNumber,
	|	NewSerialNumbers.LineNumber,
	|	SerialNumbers.Description AS NewNumber
	|FROM
	|	NewSerialNumbers AS NewSerialNumbers
	|		LEFT JOIN Catalog.SerialNumbers AS SerialNumbers
	|		ON NewSerialNumbers.NewNumber = SerialNumbers.Description
	|WHERE
	|	SerialNumbers.Owner = &Products";
	
	Query.SetParameter("Products", Products);
	Query.SetParameter("SerialNumbers",Object.SerialNumbers.Unload());
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		Object.SerialNumbers[Selection.LineNumber-1].SerialNumber = Selection.SerialNumber;
	EndDo;
	
EndProcedure

&AtClient
Procedure SeriesNumberOnChange(Item)
	
	CurRow = Object.SerialNumbers.FindByID(Items.SerialNumbersNew.CurrentRow);
	If CurRow<>Undefined Then
		CurRow.SerialNumber = Undefined;
	EndIf;
	FindRegistredSeries();
	
EndProcedure

&AtClient
Procedure SeriesNumberStartChoice(Item, ChoiceData, StandardProcessing)
	
	ChooseSerieNotification = New NotifyDescription("ChooseSerieCompletion", ThisObject);
	
	FilterStructure = New Structure("Filter", New Structure("Owner", ThisObject.Products));
	If ValueIsFilled(Items.SerialNumbersNew.CurrentData.SerialNumber) Then
		FilterStructure.Insert("CurrentRow", Items.SerialNumbersNew.CurrentData.SerialNumber);
	EndIf;
	OpenForm("Catalog.SerialNumbers.ChoiceForm", FilterStructure, ThisObject,,,,ChooseSerieNotification);
	
EndProcedure

&AtClient
Procedure ChooseSerieCompletion(ClosingResult, ExtendedParameters) Export
	
	If ClosingResult<>Undefined Then
		CurRow = Object.SerialNumbers.FindByID(Items.SerialNumbersNew.CurrentRow);
		CurRow.NewNumber	= String(ClosingResult);
		CurRow.SerialNumber = ClosingResult;
	EndIf;
	
EndProcedure

&AtClient
Procedure ChooseNumber(Command)
	
	AddChosenSerialNumbers(Items.SeriesBalances.SelectedRows);
	
EndProcedure

&AtClient
Procedure RemoveNumber(Command)
	
	RemoveChosenSerialNumbers(Items.ChosenSerialNumbers.SelectedRows);
	
EndProcedure

&AtClient
Procedure TemplateSerialNumberOnChange(Item)
	
	Items.SeriesNumber.Mask = WorkWithSerialNumbersClientServer.StringOfMaskByTemplate(TemplateSerialNumber);
	
EndProcedure

&AtClient
Procedure SeriesBalancesChoice(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	AddChosenSerialNumbers(Items.SeriesBalances.SelectedRows);
	
EndProcedure

&AtClient
Procedure SeriesBalancesDragStart(Item, DragParameters, Perform)
	
	NewValue = New Structure;
	NewValue.Insert("SelectedRows", CommonClientServer.CopyArray(DragParameters.Value));
	NewValue.Insert("Source", "SeriesBalances");
	
	DragParameters.Value = NewValue;
	
EndProcedure

&AtClient
Procedure SeriesBalancesDragCheck(Item, DragParameters, StandardProcessing, Row, Field)
	
	StandardProcessing = False;
	
	If TypeOf(DragParameters.Value) <> Type("Structure")
		Or Not DragParameters.Value.Property("Source")
		Or Not DragParameters.Value.Source = "ChosenSerialNumbers" Then
		
		DragParameters.Action = DragAction.Cancel;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SeriesBalancesDrag(Item, DragParameters, StandardProcessing, Row, Field)
	
	StandardProcessing = False;
	
	RemoveChosenSerialNumbers(DragParameters.Value.SelectedRows);
	
EndProcedure

&AtClient
Procedure ChosenSeriesChoice(Item, RowSelected, Field, StandardProcessing)
	
	RemoveNumber(Undefined);
	
EndProcedure

&AtClient
Procedure SoldOnChange(Item)
	
	Items.SeriesBalancesSold.Visible = ShowSold;
	SerialNumbersBalance.Parameters.SetParameterValue("ShowSold", ShowSold);
	
EndProcedure

&AtClient
Procedure ChosenSeriesNewNumberOpening(Item, StandardProcessing)
	
	StandardProcessing = False;
	OpenForm("Catalog.SerialNumbers.ObjectForm", New Structure("Key",Items.ChosenSerialNumbers.CurrentData.SerialNumber));
	
EndProcedure

&AtClient
Procedure OpenSerialNumber(Command)
	
	If Items.ChosenSerialNumbers.CurrentData <> Undefined Then
		
		OpenForm("Catalog.SerialNumbers.ObjectForm", New Structure("Key",Items.ChosenSerialNumbers.CurrentData.SerialNumber));
		
	EndIf; 
	
EndProcedure

&AtServer
Procedure AddExecuteAtServer()
	
	If SerialNumbersUpdatePeriodAction = Items.SerialNumbersUpdatePeriodAction.ChoiceList[0].Value Then
		
		GenerateSerialNumbersServer(SerialNumbersRowsApdateCount);
		
	ElsIf SerialNumbersUpdatePeriodAction = Items.SerialNumbersUpdatePeriodAction.ChoiceList[1].Value Then
		Items.SerialNumbersRowsChangeFrom.Visible = True;
		
		For n=SerialNumbersRowsChangeFrom To SerialNumbersRowsChangeUntil Do
			NewNumberStructure = AddSerialNumberByTemplate(n);
			
			CurrentRow = Object.SerialNumbers.Add();
			CurrentRow.NewNumber = NewNumberStructure.NewNumber;
			CurrentRow.SerialNumberNumeric = NewNumberStructure.NewNumberNumeric;
			
		EndDo;
		FindRegistredSeries();
	EndIf;
	
	VTSerialNumbers = Object.SerialNumbers.Unload();
	VTSerialNumbers.GroupBy("SerialNumber, NewNumber");
	Object.SerialNumbers.Load(VTSerialNumbers);
	
EndProcedure

&AtClient
Procedure AddExecute(Command)
	
	AddExecuteAtServer();
	
EndProcedure

&AtClient
Procedure SerialNumbersRawsUpdateActionChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	If ValueSelected = Items.SerialNumbersUpdatePeriodAction.ChoiceList[0].Value Then
		Items.SerialNumbersRowsApdateCount.Visible = True;
		Items.SerialNumbersRowsChangeFrom.Visible = False;
		Items.SerialNumbersRowsChangeUntil.Visible = False;
		SerialNumbersRowsApdateCount = Max(CountInADocument - Object.SerialNumbers.Count(), 1);
		
	ElsIf ValueSelected = Items.SerialNumbersUpdatePeriodAction.ChoiceList[1].Value Then
		Items.SerialNumbersRowsApdateCount.Visible = False;
		Items.SerialNumbersRowsChangeFrom.Visible = True;
		Items.SerialNumbersRowsChangeUntil.Visible = True;
		
		CurrentMaximumNumber = EvaluateMaximumNumberAndCount();
		SerialNumbersRowsChangeFrom = CurrentMaximumNumber + 1;
		SerialNumbersRowsChangeUntil = CurrentMaximumNumber + 1 + CountInADocument - Object.SerialNumbers.Count();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SeriesNumberOpening(Item, StandardProcessing)
	
	StandardProcessing = False;
	OpenForm("Catalog.SerialNumbers.ObjectForm", New Structure("Key",Items.SerialNumbersNew.CurrentData.SerialNumber));
	
EndProcedure

&AtClient
Procedure ChosenSerialNumbersBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure ChosenSeriesBeforeRowChange(Item, Cancel)
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure ChosenSerialNumbersDragStart(Item, DragParameters, Perform)
	
	NewValue = New Structure;
	NewValue.Insert("SelectedRows", CommonClientServer.CopyArray(DragParameters.Value));
	NewValue.Insert("Source", "ChosenSerialNumbers");
	
	DragParameters.Value = NewValue;
	
EndProcedure

&AtClient
Procedure ChosenSerialNumbersDragCheck(Item, DragParameters, StandardProcessing, Row, Field)
	
	StandardProcessing = False;
	
	If TypeOf(DragParameters.Value) <> Type("Structure")
		Or Not DragParameters.Value.Property("Source")
		Or Not DragParameters.Value.Source = "SeriesBalances" Then
		
		DragParameters.Action = DragAction.Cancel;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChosenSeriesDrag(Item, DragParameters, StandardProcessing, Row, Field)
	
	StandardProcessing = False;
	
	AddChosenSerialNumbers(DragParameters.Value.SelectedRows);
	
EndProcedure

&AtClient
Procedure ChosenSerialNumbersBeforeDeleteRow(Item, Cancel)
	
	Cancel = True;
	
	RemoveChosenSerialNumbers(Items.ChosenSerialNumbers.SelectedRows);
	
EndProcedure

&AtClient
Procedure FillByAvailability(Command)
	
	LeftToChoose = CountInADocument - Object.SerialNumbers.Count();
	If LeftToChoose>0 Then
		FillSerialNumbersByAvailability(LeftToChoose);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillSerialNumbersByAvailability(AddCount)
	
	Query = New Query;
	Query.Text = SerialNumbersBalance.QueryText;
	Query.Text = StrReplace(Query.Text, "SELECT ", "SELECT TOP "+AddCount+" ");
	For Each param In SerialNumbersBalance.Parameters.Items Do
		Query.SetParameter(String(param.Parameter), param.Value);
	EndDo;
	
	Result = Query.Execute();
	Selection = Result.Select();
	While Selection.Next() Do
		NewRow = Object.SerialNumbers.Add();
		NewRow.SerialNumber = Selection.SerialNumber;
		NewRow.NewNumber = String(Selection.SerialNumber);
		
		ListOfSelected.Add(Selection.SerialNumber);
	EndDo;
	
	SerialNumbersBalance.Parameters.SetParameterValue("ListOfSelected",ListOfSelected.UnloadValues());
	
EndProcedure

&AtClient
Procedure PagesOnCurrentPageChange(Item, CurrentPage)
	
	If CurrentPage = Items.BalancesChoice Then
		ListOfSelected.Clear();
		For Each ChNumber In Object.SerialNumbers Do
			If ValueIsFilled(ChNumber.SerialNumber) Then
				ListOfSelected.Add(ChNumber.SerialNumber);	
			EndIf;
		EndDo;
		
		SerialNumbersBalance.Parameters.SetParameterValue("ListOfSelected",ListOfSelected.UnloadValues());
	EndIf;
	
EndProcedure

&AtClient
Procedure Pickup(Command)
	
	Notification = New NotifyDescription("RecievedSerialNumbersPickup", ThisObject);
	StructureFilter = New Structure("MultipleChoice", True);
	StructureFilter.Insert("Filter", New Structure("Owner, DeletionMark", Products, False));
	
	ListFormSN = OpenForm("Catalog.SerialNumbers.Form.ChoiceForm", StructureFilter, ThisObject,,,,Notification);
	
EndProcedure

&AtClient
Procedure RecievedSerialNumbersPickup(Result, ExtendedParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	If TypeOf(Result) = type("Array") Then
		For Each Str In Result Do
			
			Items.SerialNumbersNew.AddRow();
			CurrentData = Items.SerialNumbersNew.CurrentData;
			CurrentData.NewNumber = Str;
			CurrentData.SerialNumber = Str;
			
		EndDo; 
	Else
		Items.SerialNumbersNew.AddRow();
		CurrentData = Items.SerialNumbersNew.CurrentData;
		CurrentData.NewNumber = Result;
		CurrentData.SerialNumber = Result;
	EndIf;
	
	Items.SerialNumbersNew.EndEditRow(False);	
	
EndProcedure

#EndRegion

#Region Private

#Region AddRemoveSerialNumbers

&AtClient
Procedure AddChosenSerialNumbers(SerialNumberIDs)
	
	If SerialNumberIDs.Count() = 0 Then
		Return;
	EndIf;
	
	ChosenSerialNumbersIDs = New Array;
	
	For Each RowID In SerialNumberIDs Do
		RowData = Items.SeriesBalances.RowData(RowID);
		If RowData <> Undefined Then
			ChosenSerialNumbersIDs.Add(AddChosenSerialNumber(RowData.SerialNumber));
		EndIf;
	EndDo;
	
	SeriesBalancesSelectedRows = Items.SeriesBalances.SelectedRows;
	SeriesBalancesSelectedRowsCount = SeriesBalancesSelectedRows.Count();
	If SeriesBalancesSelectedRowsCount > 1 Then
		LastID = SeriesBalancesSelectedRows[SeriesBalancesSelectedRowsCount - 1];
		SeriesBalancesSelectedRows.Clear();
		SeriesBalancesSelectedRows.Add(LastID);
	EndIf;
	
	Items.ChosenSerialNumbers.SelectedRows.Clear();
	
	For Each ChosenSerialNumbersID In ChosenSerialNumbersIDs Do
		Items.ChosenSerialNumbers.SelectedRows.Add(ChosenSerialNumbersID);
	EndDo;
	
	SerialNumbersBalance.Parameters.SetParameterValue("ListOfSelected", ListOfSelected.UnloadValues());
	
EndProcedure

&AtClient
Function AddChosenSerialNumber(SerialNumber)
	
	SerialNumbersRow = Object.SerialNumbers.Add();
	
	SerialNumbersRow.SerialNumber = SerialNumber;
	SerialNumbersRow.NewNumber = String(SerialNumber);
	
	ListOfSelected.Add(SerialNumber);
	
	Return SerialNumbersRow.GetID();
	
EndFunction

&AtClient
Procedure RemoveChosenSerialNumbers(CSN_IDs)
	
	If CSN_IDs.Count() = 0 Then
		Return;
	EndIf;
	
	RowsToBeDeleted = New Array;
	
	For Each CSN_ID In CSN_IDs Do
		
		RowsToBeDeleted.Add(Object.SerialNumbers.FindByID(CSN_ID));
		
	EndDo;
	
	For Each SerialNumberRow In RowsToBeDeleted Do
		
		FoundElement = ListOfSelected.FindByValue(SerialNumberRow.SerialNumber);
		If FoundElement <> Undefined Then
			ListOfSelected.Delete(FoundElement);
		EndIf;
		
		Object.SerialNumbers.Delete(SerialNumberRow);
		
	EndDo;
	
	SerialNumbersBalance.Parameters.SetParameterValue("ListOfSelected", ListOfSelected.UnloadValues());
	
	If Items.SeriesBalances.CurrentRow = Undefined Then
		Items.SeriesBalances.CurrentRow = 1;
	EndIf;
	
EndProcedure

#EndRegion

#Region SearchByBarcode

&AtClient
Procedure SearchByBarcode(Command)
	
	CurBarcode = "";
	ShowInputValue(New NotifyDescription("SearchByBarcodeEnd", ThisObject, New Structure("CurBarcode", CurBarcode)), CurBarcode, NStr("en = 'Enter barcode'; ru = 'Введите штрихкод';pl = 'Wprowadź kod kreskowy';es_ES = 'Introducir el código de barras';es_CO = 'Introducir el código de barras';tr = 'Barkod girin';it = 'Inserisci codice a barre';de = 'Geben Sie den Barcode ein'"));
	
EndProcedure

&AtClient
Procedure SearchByBarcodeEnd(Result, ExtendedParameters) Export
	
	CurBarcode = ?(Result = Undefined, ExtendedParameters.CurBarcode, Result);
	
	If Not IsBlankString(CurBarcode) Then
		BarcodesReceived(New Structure("Barcode, Quantity", TrimAll(CurBarcode), 1));
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure GetDataByBarCodes(StructureData)
	
	DataByBarCodes = InformationRegisters.Barcodes.GetDataByBarCodes(StructureData.BarcodesArray);
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		
		BarcodeData = DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
			And BarcodeData.Count() <> 0 Then
			
			If Not ValueIsFilled(BarcodeData.MeasurementUnit) Then
				BarcodeData.MeasurementUnit  = BarcodeData.Products.MeasurementUnit;
			EndIf;
			BarcodeData.Insert("ProductsType", BarcodeData.Products.ProductsType);
			If ValueIsFilled(BarcodeData.MeasurementUnit)
				And TypeOf(BarcodeData.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
				BarcodeData.Insert("Ratio", BarcodeData.MeasurementUnit.Ratio);
			Else
				BarcodeData.Insert("Ratio", 1);
			EndIf;
		EndIf;
	EndDo;
	
	StructureData.Insert("DataByBarCodes", DataByBarCodes);
	
EndProcedure

&AtClient
Function FillByBarcodesData(BarcodesData)
	
	UnknownBarcodes = New Array;
	IncorrectBarcodesType = New Array;
	
	If TypeOf(BarcodesData) = Type("Array") Then
		BarcodesArray = BarcodesData;
	Else
		BarcodesArray = New Array;
		BarcodesArray.Add(BarcodesData);
	EndIf;
	
	StructureData = New Structure();
	StructureData.Insert("BarcodesArray", BarcodesArray);
	StructureData.Insert("FilterProductsType", PredefinedValue("Enum.ProductsTypes.InventoryItem"));
	
	GetDataByBarCodes(StructureData);
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		BarcodeData = StructureData.DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
			And BarcodeData.Count() = 0 Then
			
			CurBarcode.Insert("Products", Products);
			CurBarcode.Insert("Characteristic", Characteristic);
			CurBarcode.Insert("Batch", Batch);
			CurBarcode.Insert("MeasurementUnit", MeasurementUnit);
			UnknownBarcodes.Add(CurBarcode);
			
		ElsIf StructureData.FilterProductsType <> BarcodeData.ProductsType Then
			IncorrectBarcodesType.Add(New Structure("Barcode,Products,ProductsType", CurBarcode.Barcode, BarcodeData.Products, BarcodeData.ProductsType));
		ElsIf Not (BarcodeData.Products = Products And BarcodeData.Characteristic = Characteristic 
			And BarcodeData.Batch = Batch And BarcodeData.MeasurementUnit = MeasurementUnit) Then
			
			MessageString = NStr("en = 'Read barcode associated with other products: %1% %2% %3% %4%'; ru = 'Считанный штрихкод привязан к другой номенклатуре: %1% %2% %3% %4%';pl = 'Odczyt kodu kreskowego, powiązanego z innymi towarami: %1% %2% %3% %4%';es_ES = 'Leer el código de barras asociado con los productos del orden: %1% %2% %3% %4%';es_CO = 'Leer el código de barras asociado con los productos del orden: %1% %2% %3% %4%';tr = 'Diğer ürünlerle ilişkili barkodu oku: %1%%2%%3%%4%';it = 'Lettura codice a barre associato con altri articoli: %1% %2% %3% %4%';de = 'Lesen Sie den mit anderen Produkten verknüpften Barcode: %1% %2% %3% %4%'");
			MessageString = StrReplace(MessageString, "%1%", BarcodeData.Products);
			MessageString = StrReplace(MessageString, "%2%", BarcodeData.Characteristic);
			MessageString = StrReplace(MessageString, "%3%", BarcodeData.Batch);
			MessageString = StrReplace(MessageString, "%4%", BarcodeData.MeasurementUnit);
			CommonClientServer.MessageToUser(MessageString);
			
		Else
			NewRow = Object.SerialNumbers.Add();
			NewRow.SerialNumber = BarcodeData.SerialNumber;
			NewRow.NewNumber = CurBarcode.Barcode;
		EndIf;
	EndDo;
	
	Return New Structure("UnknownBarcodes, IncorrectBarcodesType",UnknownBarcodes, IncorrectBarcodesType);
	
EndFunction

&AtClient
Procedure BarcodesReceived(BarcodesData) Export
	
	Modified = True;
	
	MissingBarcodes		= FillByBarcodesData(BarcodesData);
	UnknownBarcodes		= MissingBarcodes.UnknownBarcodes;
	IncorrectBarcodesType	= MissingBarcodes.IncorrectBarcodesType;
	
	ReceivedIncorrectBarcodesType(IncorrectBarcodesType);
	
	If UnknownBarcodes.Count() > 0 Then
		
		Notification = New NotifyDescription("BarcodesAreReceivedEnd", ThisObject, UnknownBarcodes);
		
		OpenForm(
			"InformationRegister.Barcodes.Form.BarcodesRegistration",
			New Structure("UnknownBarcodes", UnknownBarcodes), ThisObject,,,,Notification);
		
		Return;
		
	EndIf;
	
	BarcodesAreReceivedFragment(UnknownBarcodes);
	
EndProcedure

&AtClient
Procedure BarcodesAreReceivedEnd(ReturnParameters, Parameters) Export
	
	UnknownBarcodes = Parameters;
	
	If ReturnParameters <> Undefined Then
		
		BarcodesArray = New Array;
		
		For Each ArrayElement In ReturnParameters.RegisteredBarcodes Do
			BarcodesArray.Add(ArrayElement);
		EndDo;
		
		For Each ArrayElement In ReturnParameters.ReceivedNewBarcodes Do
			BarcodesArray.Add(ArrayElement);
		EndDo;
		
		MissingBarcodes		= FillByBarcodesData(BarcodesArray);
		UnknownBarcodes		= MissingBarcodes.UnknownBarcodes;
		IncorrectBarcodesType	= MissingBarcodes.IncorrectBarcodesType;
		ReceivedIncorrectBarcodesType(IncorrectBarcodesType);
	EndIf;
	
	BarcodesAreReceivedFragment(UnknownBarcodes);
	
EndProcedure

&AtClient
Procedure BarcodesAreReceivedFragment(UnknownBarcodes) Export
	
	For Each CurUndefinedBarcode In UnknownBarcodes Do
		
		MessageString = NStr("en = 'Barcode data is not found: %1%; quantity: %2%'; ru = 'Данные по штрихкоду не найдены: %1%; количество: %2%';pl = 'Nie znaleziono danych kodu kreskowego: %1%; ilość: %2%';es_ES = 'Datos del código de barras no encontrados: %1%; cantidad: %2%';es_CO = 'Datos del código de barras no encontrados: %1%; cantidad: %2%';tr = 'Barkod verisi bulunamadı: %1%; miktar: %2%';it = 'Il codice a barre non è stato trovato: %1%; quantità: %2%';de = 'Barcode-Daten wurden nicht gefunden: %1%; Menge: %2%'");
		MessageString = StrReplace(MessageString, "%1%", CurUndefinedBarcode.Barcode);
		MessageString = StrReplace(MessageString, "%2%", CurUndefinedBarcode.Count);
		CommonClientServer.MessageToUser(MessageString);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure ReceivedIncorrectBarcodesType(IncorrectBarcodesType) Export
	
	For Each CurhInvalidBarcode In IncorrectBarcodesType Do
		
		MessageString = NStr("en = 'Product %2% founded by barcode %1% have type %3% which is not suitable for this table section'; ru = 'Найденная по штрихкоду %1% номенклатура ""%2%"" имеет тип %3%, который не подходит для этой табличной части';pl = 'Towar %2% znaleziony na podstawie kodu kreskowego %1% ma typ %3%, który nie odpowiada tej sekcji tabeli';es_ES = 'Producto %2% encontrado por el código de barras %1% tiene el tipo %3% que no conviene a esta sección de tablas';es_CO = 'Producto %2% encontrado por el código de barras %1% tiene el tipo %3% que no conviene a esta sección de tablas';tr = '%2% barkod ile bulunan %1% ürün, bu tablo bölümü için uygun olmayan%3% tipine sahiptir.';it = 'L''articolo %2%  trovato con il codice a barre -%1%- è di tipologia %3%, che non è adatta per questa area di tabella';de = 'Produkt %2%, das vom Barcode %1% gegründet wurde, hat den Typ %3%, der für diesen Tabellenabschnitt nicht geeignet ist'");
		MessageString = StrReplace(MessageString, "%1%", CurhInvalidBarcode.Barcode);
		MessageString = StrReplace(MessageString, "%2%", CurhInvalidBarcode.Products);
		MessageString = StrReplace(MessageString, "%3%", CurhInvalidBarcode.ProductsType);
		CommonClientServer.MessageToUser(MessageString);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	CurrentData = Items.SerialNumbersNew.CurrentData;
	If CurrentData <> Undefined Then
		CurrentRowID = CurrentData.GetID(); 	
	Else
		CurrentRowID = Undefined;
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion