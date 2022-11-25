Procedure FillTSSerialNumbersByConnectionKey(DocumentObject, FillingData, NameTSInventory="Inventory", 
	TSNameSerialNumbersSource="SerialNumbers", TSNameSerialNumbersDestination="SerialNumbers") Export
	
	If NOT GetFunctionalOption("UseSerialNumbers") Then
		Return;
	EndIf;
	
	MetadataObjectName = FillingData.Metadata().Name;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED DISTINCT
	|	DocumentSerialNumbers.SerialNumber,
	|	DocumentSerialNumbers.ConnectionKey
	|FROM
	|	Document." + MetadataObjectName + "." + TSNameSerialNumbersSource + " AS DocumentSerialNumbers
	|WHERE
	|	DocumentSerialNumbers.Ref = &DocRef
	|	AND DocumentSerialNumbers.ConnectionKey IN(&ConnectionKeys)";
	
	Query.SetParameter("DocRef", FillingData.Ref);
	Query.SetParameter("ConnectionKeys", FillingData[NameTSInventory].UnloadColumn("ConnectionKey"));
	
	DocumentObject[TSNameSerialNumbersDestination].Load(Query.Execute().Unload());
	
EndProcedure

Procedure AddRowByConnectionKeyAndSerialNumber(DocumentObject,
	FillingData,
	ConnectionKey,
	SerialNumber = Undefined,
	TSNameSerialNumbersSource = "SerialNumbers",
	TSNameSerialNumbersDestination = "SerialNumbers") Export
	
	If NOT GetFunctionalOption("UseSerialNumbers") Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("ConnectionKey", ConnectionKey);
	Query.SetParameter("SerialNumber", SerialNumber);
	
	QueryResultTable = New ValueTable();
	
	If FillingData <> Undefined Then
		
		MetadataObjectName = FillingData.Metadata().Name;
		
		QueryText = 
		"SELECT ALLOWED TOP 1
		|	DocumentSerialNumbers.SerialNumber AS SerialNumber,
		|	DocumentSerialNumbers.ConnectionKey AS ConnectionKey
		|FROM
		|	&Document AS DocumentSerialNumbers
		|WHERE
		|	DocumentSerialNumbers.Ref = &Ref
		|	AND DocumentSerialNumbers.ConnectionKey = &ConnectionKey
		|	AND (&SerialNumber = UNDEFINED
		|			OR DocumentSerialNumbers.SerialNumber = &SerialNumber)";
		
		QueryText = StrReplace(QueryText, "&Document", "Document." + MetadataObjectName + "." + TSNameSerialNumbersSource);
		
		Query.Text = QueryText;
		
		Query.SetParameter("Ref", FillingData.Ref);
		
		QueryResultTable = Query.Execute().Unload();
		
	ElsIf SerialNumber <> Undefined Then
		
		Query.Text = 
		"SELECT
		|	&SerialNumber AS SerialNumber,
		|	&ConnectionKey AS ConnectionKey";
		
		QueryResultTable = Query.Execute().Unload();
		
	EndIf;
	
	If QueryResultTable.Count() > 0 Then
		DocumentObject[TSNameSerialNumbersDestination].Load(QueryResultTable);
	EndIf;
	
EndProcedure

Procedure FillTSSerialNumbersByConnectionKeySetNewConnectionKey(VTConnectionsKeyMap, DocumentObject, FillingData, NameTSInventory="Inventory", 
	TSNameSerialNumbersSource="SerialNumbers", TSNameSerialNumbersDestination="SerialNumbers", ThisWriteOff) Export
	
	If NOT GetFunctionalOption("UseSerialNumbers") Then
		Return;
	EndIf;
	
	MetadataObjectName = FillingData.Metadata().Name;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	VTConnectionsKeyMap.NewConnectionKey,
	|	VTConnectionsKeyMap.ConnectionKey
	|INTO
	|	TemporaryTable_ConnectionKeys FROM &VTConnectionsKeyMap
	|AS VTConnectionsKeyMap WHERE ThisWriteOff
	|= &ThisWriteOff ;
	|SELECT ALLOWED
	|	DISTINCT
	|	DocumentSeriaNumbers.SerialNumber, TemporaryTable_ConnectionKey.NewConnectionKey AS
	|ConnectionKey
	|	FROM Document."+MetadataObjectName+"."+TSNameSerialNumbersSource+" AS
	|	DocumentSerialNumbers INNER JOIN TemporaryTable_ConnectionKeys AS
	|		TemporaryTable_ConnectionKeys ON DocumentSerialNumbers.ConnectionKey =
	|TemporaryTable_ConnectionKeys.ConnectionKey
	|	WHERE DocumentSerialNumbers.Ref =
	|	&DocRef AND DocumentSerialNumbers.ConnectionKey IN(&ConnectionKeys)";
	
	Query.SetParameter("DocRef", FillingData.Ref);
	Query.SetParameter("ConnectionKeys", FillingData[NameTSInventory].UnloadColumn("ConnectionKey"));
	Query.SetParameter("VTConnectionsKeyMap", VTConnectionsKeyMap);
	Query.SetParameter("ThisWriteOff", ThisWriteOff);
	
	ResultVT = Query.Execute().Unload();
	For Each CurrentRow In ResultVT Do
		NewRow = DocumentObject[TSNameSerialNumbersDestination].Add();
		FillPropertyValues(NewRow, CurrentRow);
	EndDo;
	
EndProcedure

Procedure FillTSSerialNumbersInHeader(DocumentObject, FillingData, TSRow, TSNameSerialNumbers = "SerialNumbers") Export
	
	If NOT GetFunctionalOption("UseSerialNumbers") Then
		Return;
	EndIf;
	
	DocumentObject.SerialNumbersPresentation = TSRow.SerialNumbers;
	SerialNumbersRows_0 = FillingData[TSNameSerialNumbers].FindRows(New Structure("ConnectionKey", TSRow.ConnectionKey));
	DocumentObject[TSNameSerialNumbers].Load(FillingData[TSNameSerialNumbers].Unload(SerialNumbersRows_0));
		
EndProcedure

Function SerialNumbersStringFromSelection(LinesSelectionSerialNumbers, ConnectionKey) Export
	
	If NOT GetFunctionalOption("UseSerialNumbers") Then
		Return "";
	EndIf;
	
	TheStructureOfTheSearch = New Structure("ConnectionKey", ConnectionKey);
	SerialNumbersString = "";
	While LinesSelectionSerialNumbers.FindNext(TheStructureOfTheSearch) Do
		SerialNumbersString = SerialNumbersString + LinesSelectionSerialNumbers.SerialNumber + ", ";
	EndDo;
	
	If StrLen(SerialNumbersString) <> 0 Then
		SerialNumbersString = Left(SerialNumbersString, StrLen(SerialNumbersString) - 2);
	EndIf;
	
	LinesSelectionSerialNumbers.Reset();
	
	Return SerialNumbersString;
	
EndFunction

Function StringSerialNumbers(TSSerialNumbers, ConnectionKey) Export
	
	TheStructureOfTheSearch = New Structure("ConnectionKey", ConnectionKey);
	SerialNumbersString = "";
	RowsArray = TSSerialNumbers.FindRows(TheStructureOfTheSearch);
	For Each Str In RowsArray Do
		SerialNumbersString = SerialNumbersString + Str.SerialNumber + ", ";
	EndDo;
	
	If StrLen(SerialNumbersString) <> 0 Then
		SerialNumbersString = Left(SerialNumbersString, StrLen(SerialNumbersString) - 2);
	EndIf;
	
	Return SerialNumbersString;
	
EndFunction

Procedure FillSerialNumbersInInventory(DocObject, NameTSInventory = "Inventory", TSNameSerialNumbers = "SerialNumbers") Export
	
	FillConnectionKeys(DocObject, NameTSInventory);
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	Query.Text = 
	"SELECT
	|	TableInventory.LineNumber,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Quantity,
	|	TableInventory.ConnectionKey
	|INTO TTInventory
	|FROM
	|	&TableInventory AS TableInventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	NestedQuery.SerialNumber AS SerialNumber,
	|	NestedQuery.LineNumber AS LineNumber,
	|	NestedQuery.ConnectionKey,
	|	NestedQuery.Products,
	|	NestedQuery.Quantity AS Quantity
	|FROM
	|	(SELECT
	|		SerialNumbersBalance.SerialNumber AS SerialNumber,
	|		SalesInvoiceBalance.LineNumber AS LineNumber,
	|		SalesInvoiceBalance.ConnectionKey AS ConnectionKey,
	|		SalesInvoiceBalance.Products AS Products,
	|		SalesInvoiceBalance.Quantity AS Quantity
	|	FROM
	|		TTInventory AS SalesInvoiceBalance
	|			LEFT JOIN AccumulationRegister.SerialNumbers.Balance(
	|					,
	|					(&AllWarehouses
	|						OR StructuralUnit = &StructuralUnit)
	|						AND (&AllCells
	|							OR Cell = &Cell)) AS SerialNumbersBalance
	|			ON SalesInvoiceBalance.Products = SerialNumbersBalance.Products
	|				AND SalesInvoiceBalance.Characteristic = SerialNumbersBalance.Characteristic
	|				AND SalesInvoiceBalance.Batch = SerialNumbersBalance.Batch,
	|		Constant.UseSerialNumbersAsInventoryRecordDetails AS UseSerialNumbersAsInventoryRecordDetails
	|	WHERE
	|		UseSerialNumbersAsInventoryRecordDetails.Value = TRUE
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		catSerialNumbers.Ref,
	|		SalesInvoiceBalance.LineNumber,
	|		SalesInvoiceBalance.ConnectionKey,
	|		SalesInvoiceBalance.Products,
	|		SalesInvoiceBalance.Quantity
	|	FROM
	|		Constant.UseSerialNumbersAsInventoryRecordDetails AS UseSerialNumbersAsInventoryRecordDetails,
	|		TTInventory AS SalesInvoiceBalance
	|			LEFT JOIN Catalog.SerialNumbers AS catSerialNumbers
	|			ON SalesInvoiceBalance.Products = catSerialNumbers.Owner
	|	WHERE
	|		NOT catSerialNumbers.Sold
	|		AND UseSerialNumbersAsInventoryRecordDetails.Value = FALSE) AS NestedQuery
	|
	|ORDER BY
	|	SerialNumber
	|TOTALS
	|	MIN(Quantity)
	|BY
	|	LineNumber
	|AUTOORDER";
	
	Query.SetParameter("TableInventory",DocObject[NameTSInventory].Unload());
	
	If NOT ValueIsFilled(DocObject.StructuralUnit) Then
		Query.SetParameter("AllWarehouses", True);
		Query.SetParameter("StructuralUnit",DocObject.StructuralUnit);
	Else
		Query.SetParameter("AllWarehouses", False);
		Query.SetParameter("StructuralUnit",DocObject.StructuralUnit);
	EndIf;
	If NOT ValueIsFilled(DocObject.Cell) Then
		Query.SetParameter("AllCells", True);
		Query.SetParameter("Cell",DocObject.Cell);
	Else
		Query.SetParameter("AllCells", False);
		Query.SetParameter("Cell",DocObject.Cell);
	EndIf;
	
	Result = Query.Execute();
	SelectionLineNumber = Result.Select(QueryResultIteration.ByGroups);
	
	DocObject[TSNameSerialNumbers].Clear();
	While SelectionLineNumber.Next() Do
		
		QuantityFill = SelectionLineNumber.Count;
		CountSN = 0;
		
		SelectionSerialNumbers = SelectionLineNumber.Select();
		While SelectionSerialNumbers.Next() Do
			
			If CountSN>=QuantityFill Then
				Break;
			EndIf;
			
			NewRow = DocObject[TSNameSerialNumbers].Add();
			NewRow.SerialNumber = SelectionSerialNumbers.SerialNumber;
			NewRow.ConnectionKey = SelectionSerialNumbers.ConnectionKey;
			
			CountSN = CountSN + 1;
			
		EndDo;
		
		DocObject[NameTSInventory][SelectionLineNumber.LineNumber-1].SerialNumbers = StringSerialNumbers(DocObject[TSNameSerialNumbers], NewRow.ConnectionKey);
		
	EndDo;
	
EndProcedure

Procedure FillCheckingSerialNumbers(Cancel, Val Inventory, Val SerialNumbers, StructuralUnit, Val incForm, FieldNameConnectionKey = "ConnectionKey") Export
	
	// Serial numbers
	UseSerialNumbers = UseSerialNumbersBalance();
	
	incFormType = TypeOf(incForm);
	IgnoreZeroQuantity = incFormType = Type("DocumentObject.CreditNote") Or incFormType = Type("DocumentObject.DebitNote");
	
	CheckGoodsIssue = incFormType = Type("DocumentObject.SalesInvoice");
	CheckGoodsReceipt = incFormType = Type("DocumentObject.SupplierInvoice");
	
	// begin Drive.FullVersion
	IsWIP = (incFormType = Type("DocumentObject.ManufacturingOperation"));
	Filter = New Structure("ConnectionKey");
	// end Drive.FullVersion
	
	If UseSerialNumbers = True Then
	
		For Each StringInventory In Inventory Do
			
			If CheckGoodsIssue And ValueIsFilled(StringInventory.GoodsIssue)
				Or CheckGoodsReceipt And ValueIsFilled(StringInventory.GoodsReceipt)
				Or IgnoreZeroQuantity And StringInventory.Quantity = 0 Then
				Continue;
			EndIf;
			
			// begin Drive.FullVersion
			If IsWIP Then
				
				Filter.ConnectionKey = StringInventory.ActivityConnectionKey;
				OperationsLines = incForm.Activities.FindRows(Filter);
				If OperationsLines.Count() And (OperationsLines[0].StartDate = Date(1, 1, 1)) Then
					Continue;
				EndIf;
				
			EndIf;
			// end Drive.FullVersion
			
			If StringInventory.Products.UseSerialNumbers Then
				FilterSerialNumbers = New Structure("ConnectionKey", StringInventory[FieldNameConnectionKey]);
				FilterSerialNumbers = SerialNumbers.FindRows(FilterSerialNumbers);
				
				If TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOM") Then
					Ratio = UnitRatio(StringInventory.MeasurementUnit);
				Else
					Ratio = 1;
				EndIf;
				
				RowInventoryQuantity = StringInventory.Quantity * Ratio;
				
				If FilterSerialNumbers.Count() <> RowInventoryQuantity Then
					
					TSName = GetTSName(Inventory, incForm);
					
					CommonClientServer.MessageToUser(
						StringFunctionsClientServer.SubstituteParametersToString(
							NStr("en = 'The quantity of serial numbers in tabular section %1 differs from the quantity of units in the line %2.
								|Serial numbers - %3, need %4'; 
								|ru = 'Число серийных номеров табличной части %1 отличается от количества единиц в строке %2.
								|Серийных номеров - %3, требуется %4';
								|pl = 'Ilość numerów seryjnych w sekcji tabelarycznej %1 różni się od liczby jednostek w linii %2.
								|Numery seryjne -%3, potrzebne %4';
								|es_ES = 'La cantidad de los número de serie en la sección tabular %1 es diferente de la cantidad de unidades en la línea %2.
								|Número de serie - %3, necesita %4';
								|es_CO = 'La cantidad de los número de serie en la sección tabular %1 es diferente de la cantidad de unidades en la línea %2.
								|Número de serie - %3, necesita %4';
								|tr = '%1Tablo bölümündeki seri numaralarının sayısı, %2 satırındaki birim miktarından farklıdır. 
								|Seri numaraları -%3, %4 ye ihtiyaç duymaktadır';
								|it = 'La quantità di numeri di serie nella sezione tabellare %1 differisce dalla quantità di unità in linea%2.
								| Numeri di serie - %3, serve%4';
								|de = 'Die Menge der Seriennummern im Tabellenabschnitt %1 unterscheidet sich von der Menge der Einheiten in der Zeile %2.
								|Seriennummern - %3, Bedarf %4'"),
							TSName,
							StringInventory.LineNumber,
							FilterSerialNumbers.Count(),
							RowInventoryQuantity)
						,,,,
						Cancel);
				EndIf;
			EndIf;
		EndDo;
	
	EndIf;
	
	If UseSerialNumbers <> Undefined Then
		ExecuteDuplicatesControl(Cancel, Inventory, SerialNumbers, incForm, FieldNameConnectionKey);
	EndIf;
	
EndProcedure

Function GetTSName(Inventory, incForm)
	
	TSName = Mid(String(Inventory), StrFind(String(Inventory), ".", SearchDirection.FromEnd) + 1);
	
	DocMetadata = incForm.Metadata();
	For Each TabSection In DocMetadata.TabularSections Do
		
		If TabSection.Name = TSName Then
			TSName = TabSection.Synonym;
			Break;
		EndIf;
		
	EndDo;
	
	Return TSName;
	
EndFunction

Procedure ExecuteDuplicatesControl(Cancel, Val Inventory, Val SerialNumbers, Val incForm, FieldNameConnectionKey)
	
	// Checking duplicate rows.
	Query = New Query();
	Query.Text = 
	"SELECT
	|	DocumentTable.ConnectionKey AS ConnectionKey,
	|	DocumentTable.SerialNumber
	|INTO DocumentTable
	|FROM
	|	&DocumentTable AS DocumentTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(DocumentTable1.ConnectionKey) AS ConnectionKey,
	|	DocumentTable1.SerialNumber
	|FROM
	|	DocumentTable AS DocumentTable1
	|		INNER JOIN DocumentTable AS DocumentTable2
	|		ON DocumentTable1.ConnectionKey <> DocumentTable2.ConnectionKey
	|			AND DocumentTable1.SerialNumber = DocumentTable2.SerialNumber
	|
	|GROUP BY
	|	DocumentTable1.SerialNumber
	|
	|ORDER BY
	|	ConnectionKey";
	
	Query.SetParameter("DocumentTable", SerialNumbers);
	
	QueryResult = Query.Execute();
	
	If NOT QueryResult.IsEmpty() Then
		QueryResultSelection = QueryResult.Select();
		While QueryResultSelection.Next() Do
			MessageText = NStr("en = 'Serial number ""%SerialNumber%"", specified in line %LineNumber%, has already been used.'; ru = 'Серийный номер ""%SerialNumber%"", указанный в строке %LineNumber%, указан повторно.';pl = 'Numer seryjny ""%SerialNumber%"", określony w wierszu %LineNumber%, został już wykorzystany.';es_ES = 'Número de serie ""%SerialNumber%"", especificado en la línea %LineNumber%, ya se ha utilizado.';es_CO = 'Número de serie ""%SerialNumber%"", especificado en la línea %LineNumber%, ya se ha utilizado.';tr = '%LineNumber% satırında belirtilen ""%SerialNumber%"" seri numarası zaten kullanılmış.';it = 'Numero di serie ""%SerialNumber%"", specificato nella riga %LineNumber%, è già stato utilizzato.';de = 'Die Seriennummer ""%SerialNumber%"", angegeben in Zeile %LineNumber%, wurde bereits verwendet.'");
			
			InventoryRowsNumber = Inventory.Find(QueryResultSelection.ConnectionKey, FieldNameConnectionKey);
			If InventoryRowsNumber<>Undefined Then
				MessageText = StrReplace(MessageText, "%LineNumber%", InventoryRowsNumber.LineNumber);
				MessageText = StrReplace(MessageText, "%SerialNumber%", QueryResultSelection.SerialNumber);
				DriveServer.ShowMessageAboutError(
					incForm,
					MessageText,
					,
					,
					"SerialNumbers",
					Cancel
				);
			EndIf;
			

		EndDo;
	EndIf;
	
EndProcedure

Procedure FillCheckingSerialNumbersInInputField(Cancel, Val Object) Export
	
	// Serial numbers
	If UseSerialNumbersBalance() = True Then
		
		If Object.Products.UseSerialNumbers Then
			
			If TypeOf(Object.MeasurementUnit) = Type("CatalogRef.UOM") Then
				Ratio = UnitRatio(Object.MeasurementUnit);
			Else
				Ratio = 1;
			EndIf;
			
			ObjectQuantity = Object.Quantity * Ratio;
			
			If Object.SerialNumbers.Count() <> ObjectQuantity Then
				
				MessageText = NStr("en = 'The quantity of serial numbers differs from the quantity in the document.
					|Serial numbers - %1, need %2'; 
					|ru = 'Число серийных номеров не совпадает с количеством в документе.
					|Серийных номеров - %1, требуется %2';
					|pl = 'Ilość numerów seryjnych różni się od ilości w dokumencie.
					|Numery seryjne -%1, potrzeba %2';
					|es_ES = 'La cantidad de los números de serie se diferencia de la cantidad en este documento.
					|Números de serie - %1, se requiere %2';
					|es_CO = 'La cantidad de los números de serie se diferencia de la cantidad en este documento.
					|Números de serie - %1, se requiere %2';
					|tr = 'Seri numaralarının miktarı belgedeki miktardan farklı. 
					|Seri numaraları %1-, %2 ye ihtiyaç duymaktadır';
					|it = 'La quantità di numeri di serie differisce dalla quantità nel documento.
					|Numeri di serie - %1, necessari %2';
					|de = 'Die Menge der Seriennummern weicht von der Menge im Beleg ab.
					|Seriennummern - %1, benötigen %2'");
				
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					MessageText,
					Object.SerialNumbers.Count(),
					ObjectQuantity);
				
				Message = New UserMessage();
				Message.Text = MessageText;
				Message.Message();
				
				Cancel = True;
			EndIf;
		EndIf; 
	EndIf; 
	
EndProcedure

Function UseSerialNumbersBalance() Export
	
	If GetFunctionalOption("UseSerialNumbers") Then
		If GetFunctionalOption("UseSerialNumbersAsInventoryRecordDetails") Then
			Return True;
		Else
			Return False;
		EndIf;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

Function AddSerialNumber(Products, TemplateSerialNumber) Export

	MaximumNumberFromCatalog = Catalogs.SerialNumbers.CalculateMaximumSerialNumber(Products, TemplateSerialNumber);
	Return AddSerialNumberByTemplate(MaximumNumberFromCatalog+1, TemplateSerialNumber);
	
EndFunction

Function AddSerialNumberByTemplate(CurrentMaximumNumber, TemplateSerialNumber)
		
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

Function UnitRatio(MeasurementUnit) Export
	
	Return Common.ObjectAttributeValue(MeasurementUnit,"Factor");
	
EndFunction

Procedure FillConnectionKeys(Object, TSName, FieldNameConnectionKey = "ConnectionKey")
	
	Index = 0;
	For Each TSRow In Object[TSName] Do
		If Not ValueIsFilled(TSRow[FieldNameConnectionKey]) Then
			WorkWithSerialNumbersClientServer.FillConnectionKey(Object[TSName], TSRow, FieldNameConnectionKey);
		EndIf;
		If Index < TSRow[FieldNameConnectionKey] Then
			Index = TSRow[FieldNameConnectionKey];
		EndIf;
	EndDo;
	
EndProcedure

Function GetSerialNumbersFromStorage(Object, AddressInventoryInStorage, ConnectionKey, ParametersFieldNames = Undefined) Export
	
	NameTSInventory			= "Inventory";
	TSNameSerialNumbers		= "SerialNumbers";
	FieldNameConnectionKey	= "ConnectionKey";
	ThisIsReciept			= False;
	
	If ParametersFieldNames <> Undefined AND TypeOf(ParametersFieldNames) = Type("Structure") Then
		
		If ParametersFieldNames.Property("NameTSInventory") Then
			NameTSInventory = ParametersFieldNames.NameTSInventory;
		EndIf;
		
		If ParametersFieldNames.Property("TSNameSerialNumbers") Then
			TSNameSerialNumbers = ParametersFieldNames.TSNameSerialNumbers;
		EndIf;
		
		If ParametersFieldNames.Property("FieldNameConnectionKey") Then
			FieldNameConnectionKey = ParametersFieldNames.FieldNameConnectionKey;
		EndIf;
		
		If ParametersFieldNames.Property("ThisIsReciept") Then
			ThisIsReciept = ParametersFieldNames.ThisIsReciept;
		EndIf;
		
	EndIf;
	
	TableForImport			= GetFromTempStorage(AddressInventoryInStorage);
	SelectedSerialNumbers	= TableForImport.Count();
	QuantityChanged			= False;
	
	// Clear old versions
	FilterSerialNumbersOfCurrentString	= New Structure("ConnectionKey", ConnectionKey);
	DeleteRowsArray						= New FixedArray(Object[TSNameSerialNumbers].FindRows(FilterSerialNumbersOfCurrentString));
	
	For Each RowDelete In DeleteRowsArray Do
		Object[TSNameSerialNumbers].Delete(RowDelete);	
	EndDo;
	
	// Generate presentation for inventory line
	StringPresentationOfSerialNumbers = "";
	For Each ImportRow In TableForImport Do
		
		NewRow = Object[TSNameSerialNumbers].Add();
		
		FillPropertyValues(NewRow, ImportRow);
		
		If NewRow.Property("Series") Then
			StringPresentationOfSerialNumbers = StringPresentationOfSerialNumbers + NewRow.Series + "; ";
		Else
			StringPresentationOfSerialNumbers = StringPresentationOfSerialNumbers + NewRow.SerialNumber + "; ";
		EndIf;
		
		NewRow.ConnectionKey = ConnectionKey;
	EndDo;
	
	StringPresentationOfSerialNumbers = Left(StringPresentationOfSerialNumbers, Min(StrLen(StringPresentationOfSerialNumbers) - 2, 150));
	
	FilterSerialNumbersTS = New Structure(FieldNameConnectionKey, ConnectionKey);
	InventoryRows = Object[NameTSInventory].FindRows(FilterSerialNumbersTS);
	
	For Each Str In InventoryRows Do
		
		Str[FieldNameConnectionKey] = ConnectionKey;
		
		If ThisIsReciept Then
			Str.SerialNumbersPosting = StringPresentationOfSerialNumbers;
		Else
			Str.SerialNumbers = StringPresentationOfSerialNumbers;
		EndIf;
		
		If Str.Property("MeasurementUnit") Then
			
			If NOT ThisIsReciept Then
				If TypeOf(Str.MeasurementUnit) = Type("CatalogRef.UOM") Then
					Ratio = Str.MeasurementUnit.Factor;
				Else
					Ratio = 1;
				EndIf;
			Else
				If TypeOf(Str.MeasurementUnitPosting) = Type("CatalogRef.UOM") Then
					Ratio = Str.MeasurementUnitPosting.Factor;
				Else
					Ratio = 1;
				EndIf;
			EndIf;
			
			QuantityOfEntireUnits = Int(SelectedSerialNumbers / Ratio);
			
			If Str.Quantity < QuantityOfEntireUnits Then
				Str.Quantity = QuantityOfEntireUnits;
				QuantityChanged = True;
			EndIf;
			
		ElsIf SelectedSerialNumbers <> Str.Quantity Then
			Str.Quantity = SelectedSerialNumbers;
			QuantityChanged = True;
		EndIf;
		
		Break;
		
	EndDo;
	
	Return QuantityChanged;
	
EndFunction

Function GetSerialNumbersFromStorageForInputField(Object, AddressInventoryInStorage) Export
	
	TableForImport = GetFromTempStorage(AddressInventoryInStorage);
	SelectedSerialNumbers = TableForImport.Count();
	QuantityChanged = False;
	
	// Clear old versions
	Object.SerialNumbers.Clear();
	
	// Generate presentation for inventory line
	StringPresentationOfSerialNumbers = "";
	For Each ImportRow In TableForImport Do
		
		NewRow = Object.SerialNumbers.Add();
		FillPropertyValues(NewRow, ImportRow);
		
		StringPresentationOfSerialNumbers = StringPresentationOfSerialNumbers + NewRow.SerialNumber+"; ";
	EndDo;
	StringPresentationOfSerialNumbers = Left(StringPresentationOfSerialNumbers, Min(StrLen(StringPresentationOfSerialNumbers)-2,150));
	
	Object.SerialNumbersPresentation = StringPresentationOfSerialNumbers;
	If Object.Quantity < SelectedSerialNumbers Then
		Object.Quantity = SelectedSerialNumbers;
		QuantityChanged = True;
	EndIf;
	
	Return QuantityChanged;
	
EndFunction

Function SerialNumberPickParameters(DocObject, FormUID, RowID, PickMode = Undefined, TSName = "Inventory", TSNameSerialNumbers = "SerialNumbers", FieldNameConnectionKey = "ConnectionKey",
	ThisIsReciept = False) Export
	
	CurRowData = DocObject[TSName].FindByID(RowID);	
	If CurRowData[FieldNameConnectionKey]=0 Then
		FillConnectionKeys(DocObject, TSName, FieldNameConnectionKey);
	EndIf;
	
	ParametersOfSerialNumbers = PrepareParametersOfSerialNumbers(DocObject, CurRowData, FormUID, TSName, TSNameSerialNumbers, FieldNameConnectionKey, ThisIsReciept);
	If PickMode = Undefined And UseSerialNumbersBalance() = True Then
		PickMode = True;
	ElsIf PickMode = Undefined Then
		PickMode = False;
	EndIf;
	ParametersOfSerialNumbers.Insert("PickMode", PickMode);
	
	Return ParametersOfSerialNumbers;
	
EndFunction

Function PrepareParametersOfSerialNumbers(DocObject, CurRowData, FormUID, TSName = "Inventory", TSNameSerialNumbers = "SerialNumbers", FieldNameConnectionKey = "ConnectionKey",
	ThisIsReciept = False) Export
	
	SerialNumbersData = New Structure;
	
	FilterSerialNumbersOfCurrentString = New Structure("ConnectionKey", CurRowData[FieldNameConnectionKey]);
	SerialNumbersOfCurrentString = DocObject[TSNameSerialNumbers].FindRows(FilterSerialNumbersOfCurrentString);
	SerialNumbersData.Insert("SerialNumbersOfCurrentString", DocObject[TSNameSerialNumbers].Unload(SerialNumbersOfCurrentString));
	
	If ThisIsReciept Then
		FilterCurrentProductRows = New Structure("ProductsPosting, CharacteristicPosting");
	Else
		FilterCurrentProductRows = New Structure("Products, Characteristic");
	EndIf;
	
	SalesDocument = Undefined;
	If GetFunctionalOption("UseSerialNumbersAsInventoryRecordDetails") Then 
		If TypeOf(DocObject.Ref) = Type("DocumentRef.GoodsReceipt")
			And DocObject.OperationType = Enums.OperationTypesGoodsReceipt.SalesReturn Then
			
			If Not ValueIsFilled(CurRowData.SalesDocument) Then
				
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Fill the Sales invoice document in the line %1.'; ru = 'Укажите инвойс покупателю в строке %1.';pl = 'Wypełnij dokument Faktura sprzedaży w wierszu %1.';es_ES = 'Rellene el documento de la factura de venta en la línea %1.';es_CO = 'Rellene el documento de la factura de venta en la línea %1.';tr = '%1 satırında Satış faturası belgesini doldurun.';it = 'Compilare il documento di Fattura di vendita nella riga %1.';de = 'Füllen Sie das Dokument Verkaufsrechnung in der Zeile %1.'"),
				CurRowData.LineNumber);
				
				CommonClientServer.MessageToUser(MessageText);
				
				Return New Structure();
			EndIf;
			If TypeOf(CurRowData.SalesDocument) = Type("DocumentRef.SalesInvoice") Then 
				SalesDocument = CurRowData.SalesDocument;
			EndIf;
		ElsIf TypeOf(DocObject.Ref) = Type("DocumentRef.CreditNote")
			And DocObject.OperationKind = Enums.OperationTypesCreditNote.SalesReturn Then 
			

			If Not DocObject.Ref.BasisDocumentInTabularSection And TypeOf(DocObject.Ref.BasisDocument) = Type("DocumentRef.SalesInvoice") Then
				DocAttributes = Common.ObjectAttributesValues(DocObject.Ref, "BasisDocument");
				If Not ValueIsFilled(DocAttributes.BasisDocument) Then
					
					MessageText = NStr("en = 'Fill the Sales invoice document in the field Base document.'; ru = 'Укажите инвойс покупателю в поле ""Документ-основание"".';pl = 'Wypełnij dokument Faktura sprzedaży w polu Dokument źródłowy.';es_ES = 'Rellene el documento de la factura de venta en el campo Documento base.';es_CO = 'Rellene el documento de la factura de venta en el campo Documento base.';tr = 'Temel belge alanında Satış faturası belgesini doldurun.';it = 'Compilare il documento di Fattura di vendita nel campo Documento di base.';de = 'Füllen Sie das Dokument Verkaufsrechnung im Feld Basisbeleg.'");
					CommonClientServer.MessageToUser(MessageText);
					
					Return New Structure();
				EndIf;
				SalesDocument = DocAttributes.BasisDocument;
			ElsIf TypeOf(CurRowData.SalesDocument) = Type("DocumentRef.SalesInvoice")Then
				If Not ValueIsFilled(CurRowData.SalesDocument) Then

					
					MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Fill the Sales invoice document in the line %1.'; ru = 'Укажите инвойс покупателю в строке %1.';pl = 'Wypełnij dokument Faktura sprzedaży w wierszu %1.';es_ES = 'Rellene el documento de la factura de venta en la línea %1.';es_CO = 'Rellene el documento de la factura de venta en la línea %1.';tr = '%1 satırında Satış faturası belgesini doldurun.';it = 'Compilare il documento di Fattura di vendita nella riga %1.';de = 'Füllen Sie das Dokument Verkaufsrechnung in der Zeile %1.'"),
					CurRowData.LineNumber);
					
					CommonClientServer.MessageToUser(MessageText);
					
					Return New Structure();
				EndIf;
				SalesDocument = CurRowData.SalesDocument;
			EndIf;
			
		EndIf;
	EndIf;
	                                    
	FillPropertyValues(FilterCurrentProductRows, CurRowData);
	CurrentProductRows = DocObject[TSName].FindRows(FilterCurrentProductRows);
	SerialNumbersOfCurrentProductRows = New Array;
	
	For Each ProductRow In CurrentProductRows Do
		If ProductRow = CurRowData Then
			Continue;
		EndIf;
		
		FilterSerialNumbersOfCurrentString = New Structure("ConnectionKey", ProductRow[FieldNameConnectionKey]);
		SerialNumbersOfCurrentString = DocObject[TSNameSerialNumbers].FindRows(FilterSerialNumbersOfCurrentString);
		
		For Each SerialNumberRow In SerialNumbersOfCurrentString Do
			SerialNumbersOfCurrentProductRows.Add(SerialNumberRow);
		EndDo;
	EndDo;
	
	SerialNumbersData.Insert("SerialNumbersOfCurrentProduct", DocObject[TSNameSerialNumbers].Unload(SerialNumbersOfCurrentProductRows));
	
	AddressInTemporaryStorage = PutToTempStorage(SerialNumbersData, FormUID);
	
	InventoryParameter = New Structure();
	InventoryParameter.Insert("ConnectionKey",	CurRowData[FieldNameConnectionKey]);
	InventoryParameter.Insert("Products",		?(ThisIsReciept, CurRowData.ProductsPosting, CurRowData.Products));
	InventoryParameter.Insert("Characteristic",	?(ThisIsReciept, CurRowData.CharacteristicPosting, CurRowData.Characteristic));
	InventoryParameter.Insert("Quantity",		CurRowData.Quantity);
	
	OpenParameters = New Structure();
	OpenParameters.Insert("Inventory",					InventoryParameter);
	OpenParameters.Insert("OwnerFormUUID",				FormUID);
	OpenParameters.Insert("AddressInTemporaryStorage",	AddressInTemporaryStorage);
	OpenParameters.Insert("DocRef",						DocObject.Ref);
	
	If Not SalesDocument = Undefined Then
		OpenParameters.Insert("DocSalesInvoice", SalesDocument);
	EndIf;
	
	If DocObject.Property("Company") Then
		OpenParameters.Insert("Company", DriveServer.GetCompany(DocObject.Company));
	EndIf;
	
	If CurRowData.Property("StructuralUnit") Then
		OpenParameters.Insert("StructuralUnit", CurRowData.StructuralUnit);
	ElsIf DocObject.Property("StructuralUnit") Then
		OpenParameters.Insert("StructuralUnit", DocObject.StructuralUnit);
	ElsIf DocObject.Property("StructuralUnitReserve") Then
		OpenParameters.Insert("StructuralUnit", DocObject.StructuralUnitReserve);
	EndIf;
	
	If CurRowData.Property("Cell") Then
		OpenParameters.Insert("Cell", CurRowData.Cell);
	ElsIf DocObject.Property("Cell") Then
		OpenParameters.Insert("Cell", DocObject.Cell);
	EndIf;
	
	If CurRowData.Property("MeasurementUnit") Then
		OpenParameters.Inventory.Insert("MeasurementUnit", CurRowData.MeasurementUnit);
		If TypeOf(CurRowData.MeasurementUnit) = Type("CatalogRef.UOM") Then
			OpenParameters.Inventory.Insert("Ratio", CurRowData.MeasurementUnit.Factor);
		Else
			OpenParameters.Inventory.Insert("Ratio", 1);
		EndIf;
	EndIf;
	
	If CurRowData.Property("Batch") Then
		OpenParameters.Inventory.Insert("Batch", CurRowData.Batch);
	Else
		OpenParameters.Inventory.Insert("Batch", Catalogs.ProductsBatches.EmptyRef());
	EndIf;
	
	Return OpenParameters;
	
EndFunction

Function SerialNumberPickParametersInInputField(DocObject, FormUID, PickMode = Undefined) Export
	
	// If the product is one per document (not in the table section, but in requisites)
	AddressInTemporaryStorage = PutToTempStorage(DocObject.SerialNumbers.Unload(), FormUID);
	
	ParametersOfSerialNumbers = New Structure("Inventory, OwnerFormUUID, AddressInTemporaryStorage, DocRef", 
		New Structure("Products, Characteristic", 
			DocObject.Products,
			DocObject.Characteristic),
			FormUID,
			AddressInTemporaryStorage,
			DocObject.Ref
			);
			
	If DocObject.Property("Quantity") Then
		ParametersOfSerialNumbers.Inventory.Insert("Quantity", DocObject.Quantity);
	Else
		ParametersOfSerialNumbers.Inventory.Insert("Quantity", 1);
	EndIf;
	
	If DocObject.Property("StructuralUnit") Then
		ParametersOfSerialNumbers.Insert("StructuralUnit", DocObject.StructuralUnit);
	EndIf;
	If DocObject.Property("Cell") Then
		ParametersOfSerialNumbers.Insert("Cell", DocObject.Cell);
	EndIf;
	If DocObject.Property("Batch") Then
		ParametersOfSerialNumbers.Inventory.Insert("Batch", DocObject.Batch);
	Else
		ParametersOfSerialNumbers.Inventory.Insert("Batch", Catalogs.ProductsBatches.EmptyRef());
	EndIf; 		
	If DocObject.Property("MeasurementUnit") Then
		ParametersOfSerialNumbers.Inventory.Insert("MeasurementUnit", DocObject.MeasurementUnit);
		If TypeOf(DocObject.MeasurementUnit)=Type("CatalogRef.UOM") Then
		    ParametersOfSerialNumbers.Inventory.Insert("Ratio", DocObject.MeasurementUnit.Ratio);
		Else
			ParametersOfSerialNumbers.Inventory.Insert("Ratio", 1);
		EndIf;
	EndIf;
	
	////////////////////////////////////////////////////
	If PickMode=Undefined AND GetFunctionalOption("UseSerialNumbersAsInventoryRecordDetails") Then
		PickMode = True;
	Else
		PickMode = False;
	EndIf;
	ParametersOfSerialNumbers.Insert("PickMode", PickMode);
	If Common.HasObjectAttribute("Company", DocObject.Ref.Metadata()) Then
		ParametersOfSerialNumbers.Insert("Company", DriveServer.GetCompany(DocObject.Company));
	EndIf; 
	
	Return ParametersOfSerialNumbers;
	
EndFunction

Procedure SetActualSerialNumbersInTabularSection(DocumentData, TabularSectionRow, SerialNumbers) Export
	
	Query = New Query;
	Query.Text = QueryTextSerialNumbersByDocument(DocumentData.Ref);
	
	Query.SetParameter("Products", TabularSectionRow.Products);
	Query.SetParameter("SalesDocument", TabularSectionRow.SalesDocument);
	
	QueryResult = Query.Execute().Unload();
	
	ExcludeSerialNumbersReturn = New Array;
	
	If QueryResult.Count()>0 Then
		ExcludeSerialNumbersReturn = QueryResult.UnloadColumn("SerialNumber");
	EndIf;
	
	ArraySerialNumbersSalesDoc = GetSerialNumberFromRegisterByDocSales(DocumentData, TabularSectionRow,ExcludeSerialNumbersReturn);
	
	For Each SerialNunber In ArraySerialNumbersSalesDoc Do
		SerialNumbersRow = SerialNumbers.Add();
		SerialNumbersRow.SerialNumber = SerialNunber.Ref;
		SerialNumbersRow.ConnectionKey = TabularSectionRow.LineNumber;

		TabularSectionRow.SerialNumbers = TabularSectionRow.SerialNumbers 
										+ ?(ValueIsFilled(TabularSectionRow.SerialNumbers),"; ","")
										+ SerialNunber.Description;
	EndDo;
EndProcedure

Function QueryTextSerialNumbersByDocument(Ref) Export
	
	If TypeOf(Ref) = Type("DocumentRef.GoodsReceipt") Then
		Text =
		"SELECT ALLOWED
		|	GoodsReceiptSerialNumbers.SerialNumber AS SerialNumber,
		|	GoodsReceiptSerialNumbers.Ref AS Ref
		|FROM
		|	Document.GoodsReceipt.Products AS GoodsReceiptProducts
		|		LEFT JOIN Document.GoodsReceipt.SerialNumbers AS GoodsReceiptSerialNumbers
		|		ON GoodsReceiptProducts.Ref = GoodsReceiptSerialNumbers.Ref
		|WHERE
		|	GoodsReceiptProducts.SalesDocument = &SalesDocument
		|	AND GoodsReceiptProducts.Products = &Products
		|	AND GoodsReceiptProducts.Ref.Posted"; 
	Else
		Text =
		"SELECT ALLOWED
		|	CreditNoteInventory.Ref AS Ref,
		|	CreditNoteSerialNumbers.SerialNumber AS SerialNumber
		|FROM
		|	Document.CreditNote.Inventory AS CreditNoteInventory
		|		FULL JOIN Document.CreditNote.SerialNumbers AS CreditNoteSerialNumbers
		|		ON CreditNoteInventory.Ref = CreditNoteSerialNumbers.Ref
		|WHERE
		|	CreditNoteInventory.Products = &Products
		|	AND CreditNoteInventory.SalesDocument = &SalesDocument
		|	AND CreditNoteInventory.Ref.Posted"; 
	EndIf;
	
	Return Text;
	
EndFunction

Function GetSerialNumberFromRegisterByDocSales(DocumentData, TabularSectionRow, ArraySerialNumbers)
	
	Query = New Query;
	Query.Text = QueryTextSeriesBalancesByDocument();
	
	Query.SetParameter("Products",        TabularSectionRow.Products);
	Query.SetParameter("Company",         DriveServer.GetCompany(DocumentData.ThisObject.Company));
	Query.SetParameter("StructuralUnit",  DocumentData.ThisObject.StructuralUnit);
	Query.SetParameter("AllWarehouses",   False);
	Query.SetParameter("Cell",            DocumentData.ThisObject.Cell);
	Query.SetParameter("ThisDocument",    TabularSectionRow.SalesDocument);
	Query.SetParameter("AllCells",        False);
	Query.SetParameter("Characteristic",  TabularSectionRow.Characteristic);
	Query.SetParameter("MeasurementUnit", TabularSectionRow.MeasurementUnit);
	Query.SetParameter("ListOfSelected",  ArraySerialNumbers);
	Query.SetParameter("CompleteListOfSelected", new Array);
	
	If ValueIsFilled(TabularSectionRow.Batch) Then
		Query.SetParameter("ReferentialBatch", True);
		Query.SetParameter("Batch", Catalogs.ProductsBatches.EmptyRef());
	Else
		Query.SetParameter("ReferentialBatch", False);
		Query.SetParameter("Batch", TabularSectionRow.Batch);
	EndIf;
	QueryResult = Query.Execute().Unload();

	If QueryResult.Count()>0 Then
		Return QueryResult.UnloadColumn("SerialNumber");
	EndIf;
	Return New Array;
EndFunction
	

Function QueryTextSeriesBalancesByDocument()
	
	RequestText =
	"SELECT ALLOWED DISTINCT
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
