#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.Pricing.InitializeDocumentData(Ref, AdditionalProperties);
	
	Documents.Pricing.CheckBeforePosting(ThisObject, AdditionalProperties, Cancel);
	
	If NOT Cancel Then
		
		// Preparation of records sets.
		DriveServer.PrepareRecordSetsForRecording(ThisObject);
		
		DriveServer.ReflectPrices(AdditionalProperties, RegisterRecords, Cancel);
		
		// Writing of record sets
		DriveServer.WriteRecordSets(ThisObject);
		
	EndIf;
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing) Export
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData, , "PriceKind");
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	Query = New Query;
	Query.SetParameter("ProductsTable", Inventory.Unload());
	Query.Text =
	"SELECT
	|	ProductsTable.Products AS Products,
	|	ProductsTable.Characteristic AS Characteristic
	|INTO TempProductsTable
	|FROM
	|	&ProductsTable AS ProductsTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductsTable.Products AS Products,
	|	ProductsTable.Characteristic AS Characteristic
	|FROM
	|	TempProductsTable AS ProductsTable
	|
	|GROUP BY
	|	ProductsTable.Products,
	|	ProductsTable.Characteristic
	|
	|HAVING
	|	COUNT(*) > 1";
	
	ResultTable = Query.Execute().Unload();
	
	For Each Row In ResultTable Do
		
		If ValueIsFilled(Row.Characteristic) Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'The row %1 (%2) is duplicated.'; ru = 'Строка %1 (%2) дублируется.';pl = 'Wiersz %1 (%2) powtarza się.';es_ES = 'La fila %1(%2) está duplicada.';es_CO = 'La fila %1(%2) está duplicada.';tr = 'Satır %1 (%2) çoğaltıldı.';it = 'La riga %1 (%2) è duplicata!';de = 'Die Zeile %1 (%2) ist dupliziert.'"),
				Row.Products,
				Row.Characteristic)
		Else
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'The row %1 is duplicated.'; ru = 'Строка %1 дублируется.';pl = 'Wiersz %1 powtarza się.';es_ES = 'La fila %1 está duplicada.';es_CO = 'La fila %1 está duplicada.';tr = 'Satır %1 çoğaltıldı.';it = 'La riga %1 è duplicata!';de = 'Die Zeile %1 ist dupliziert.'"),
				Row.Products)
		EndIf;
		
		CommonClientServer.MessageToUser(MessageText, , , ,Cancel);
		
	EndDo;
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	Author = Users.CurrentUser();
	
EndProcedure

#EndRegion

#EndIf