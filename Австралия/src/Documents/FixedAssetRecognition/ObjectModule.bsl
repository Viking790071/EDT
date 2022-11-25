#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Executes preliminary control.
//
Procedure RunPreliminaryControl(Cancel)
	
	// Check Row duplicates.
	Query = New Query();
	
	Query.Text = 
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.FixedAsset
	|INTO DocumentTable
	|FROM
	|	&DocumentTable AS DocumentTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(TableOfDocument1.LineNumber) AS LineNumber,
	|	TableOfDocument1.FixedAsset
	|FROM
	|	DocumentTable AS TableOfDocument1
	|		INNER JOIN DocumentTable AS TableOfDocument2
	|		ON TableOfDocument1.LineNumber <> TableOfDocument2.LineNumber
	|			AND TableOfDocument1.FixedAsset = TableOfDocument2.FixedAsset
	|
	|GROUP BY
	|	TableOfDocument1.FixedAsset
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("DocumentTable", FixedAssets);
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		QueryResultSelection = QueryResult.Select();
		While QueryResultSelection.Next() Do
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
							NStr("en = 'Fixed asset ""%1"" from the line %2 of the ""Fixed assets"" list is duplicated.'; ru = 'Основное средство ""%1"", указанное в строке %2 списка ""Основные средства"", указано повторно.';pl = 'Środek trwały ""%1"" z wiersza %2 listy ""Środki trwałe"" jest zduplikowany.';es_ES = 'El activo fijo ""%1"" de la línea %2 de la lista de ""Activos fijos"" está duplicado.';es_CO = 'El activo fijo ""%1"" de la línea %2 de la lista de ""Activos fijos"" está duplicado.';tr = '""Sabit kıymetler"" listesinin %2 satırından ""%1"" sabit kıymeti kopyalanır.';it = 'Il cespite ""%1"" dalla linea %2 dell''elenco ""Cespiti"" è duplicato.';de = 'Das Anlagevermögen ""%1"" aus der Zeile %2 der Liste ""Anlagevermögen"" wird dupliziert.'"),
							QueryResultSelection.LineNumber,
							QueryResultSelection.FixedAsset);
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"FixedAssets",
				QueryResultSelection.LineNumber,
				"FixedAsset",
				Cancel
			);

		EndDo;
	EndIf;
	
	// Check cost.
	TotalOriginalCost = 0;
	
	Query = New Query;
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	Query.SetParameter("FixedAssetsList", FixedAssets.UnloadColumn("FixedAsset"));
	
	Query.Text =
	"SELECT
	|	ISNULL(SUM(FixedAssets.InitialCost), 0) AS InitialCost
	|FROM
	|	Catalog.FixedAssets AS FixedAssets
	|WHERE
	|	FixedAssets.Ref IN(&FixedAssetsList)";
	
	QuerySelection = Query.Execute().Select();
	
	If QuerySelection.Next() Then
		TotalOriginalCost = QuerySelection.InitialCost;
	EndIf;
	
	If TotalOriginalCost <> Amount Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'The fixed asset cost: %1 mismatches its initial costs: %2'; ru = 'Стоимость основного средства: %1 , не соответствует сумме его первоначальных стоимостей: %2';pl = 'Koszt środka trwałego: %1 jest niezgodny z początkowymi kosztami: %2';es_ES = 'El coste del activo fijo: %1 no corresponde a sus costes iniciales: %2';es_CO = 'El coste del activo fijo: %1 no corresponde a sus costes iniciales: %2';tr = 'Sabit kıymet maliyeti: %1 ilk maliyeti ile eşleşmiyor: %2';it = 'Il costo del cespite: %1 non corrisponde al costo iniziale: %2';de = 'Die Anlagekosten: %1 die Anschaffungskosten stimmen nicht überein: %2'"),
						TrimAll(String(Amount)),
						TrimAll(String(TotalOriginalCost)));
		DriveServer.ShowMessageAboutError(
			ThisObject,
			MessageText,
			Undefined,
			Undefined,
			"",
			Cancel
		);
	EndIf;
	
	Query.Text =
	"SELECT ALLOWED
	|	NestedSelect.FixedAsset AS FixedAsset
	|FROM
	|	(SELECT
	|		FixedAssetStatus.FixedAsset AS FixedAsset,
	|		SUM(CASE
	|				WHEN FixedAssetStatus.State = VALUE(Enum.FixedAssetStatus.AcceptedForAccounting)
	|					THEN 1
	|				ELSE -1
	|			END) AS CurrentState
	|	FROM
	|		InformationRegister.FixedAssetStatus AS FixedAssetStatus
	|	WHERE
	|		FixedAssetStatus.Recorder <> &Ref
	|		AND FixedAssetStatus.Company = &Company
	|		AND FixedAssetStatus.FixedAsset IN(&FixedAssetsList)
	|	
	|	GROUP BY
	|		FixedAssetStatus.FixedAsset) AS NestedSelect
	|WHERE
	|	NestedSelect.CurrentState > 0";
	
	Query.SetParameter("Ref", Ref);
	
	QueryResult = Query.Execute();
	ArrayVAStatus = QueryResult.Unload().UnloadColumn("FixedAsset");
	
	For Each RowOfFixedAssets In FixedAssets Do
			
		If ArrayVAStatus.Find(RowOfFixedAssets.FixedAsset) <> Undefined Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
							NStr("en = 'The current status of the ""%1"" fixed asset from the line %2 of the ""Fixed assets"" list is ""Recognized"".'; ru = 'Для основного средства ""%1"" указанного в строке %2 списка ""Основные средства"", текущее состояние ""Принят к учету"".';pl = 'Bieżący status środka trwałego ""%1"" z wiersza %2 listy ""Środki trwałe"" to ""Przyjęty"".';es_ES = 'El estado actual del activo fijo ""%1"" de la línea %2 de la lista de ""Activos fijos"" es ""Reconocido"".';es_CO = 'El estado actual del activo fijo ""%1"" de la línea %2 de la lista de ""Activos fijos"" es ""Reconocido"".';tr = '""Sabit kıymetler"" listesinin %2 satırından ""%1"" sabit kıymetin mevcut durumu ""Tanındı"" şeklindedir.';it = 'Lo stato corrente del cespite ""%1"" della linea %2 dell''elenco ""Cespite"" è ""Riconosciuto"".';de = 'Der aktuelle Status der ""%1"" Anlage aus der Zeile%2 der Liste ""Anlagevermögen"" lautet ""Erkannt"".'"),
							TrimAll(String(RowOfFixedAssets.FixedAsset)),
							String(RowOfFixedAssets.LineNumber));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"FixedAssets",
				RowOfFixedAssets.LineNumber,
				"FixedAsset",
				Cancel
			);
		EndIf;
		
	EndDo;
	
EndProcedure

// Procedure of filling the document on the basis.
//
// Parameters:
//  FillingData - Structure - Data on filling the document.
//	
Procedure FillByFixedAssets(FillingData)
	
	NewRow = FixedAssets.Add();
	NewRow.FixedAsset = FillingData;
	NewRow.AccrueDepreciation = True;
	NewRow.AccrueDepreciationInCurrentMonth = True;
	
	User = Users.CurrentUser();
	SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainDepartment");
	MainDepartment = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.BusinessUnits.MainDepartment);
	
	NewRow.StructuralUnit = MainDepartment;
	NewRow.ExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("DepreciationCharge");
	NewRow.RegisterExpense = True;
	
EndProcedure

#EndRegion

#Region EventsHandlers

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If TypeOf(FillingData) = Type("CatalogRef.FixedAssets") Then
		FillByFixedAssets(FillingData);
	EndIf;
	
EndProcedure

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not Constants.UseSeveralLinesOfBusiness.Get() Then
		
		For Each RowFixedAssets In FixedAssets Do
			
			If RowFixedAssets.ExpenseItem.IncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.AdministrativeExpenses Then
				
				RowFixedAssets.BusinessLine = Catalogs.LinesOfBusiness.MainLine;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(ThisObject, Cancel);
	// End Change of approved documents
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	AdditionalProperties.Insert("Posted", Posted);
	
	InventoryOwnershipServer.FillHeaderAttribute(ThisObject, WriteMode, Cancel);
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	// Preliminary control execution.
	RunPreliminaryControl(Cancel);
	
	BatchesServer.CheckFilling(ThisObject, Cancel);
	
	// Correctness of filling.
	For Each RowOfFixedAssets In FixedAssets Do
			
		If RowOfFixedAssets.FixedAsset.DepreciationMethod = Enums.FixedAssetDepreciationMethods.Linear
		   AND RowOfFixedAssets.UsagePeriodForDepreciationCalculation = 0 Then
			MessageText = NStr("en = 'For fixed asset ""%FixedAsset%"" indicated in string %LineNumber% of list ""Fixed assets"" should be filled with ""Useful life to calculate depreciation"".'; ru = 'Для основного средства ""%FixedAsset%"" указанного в строке %LineNumber% списка ""Основные средства"", должен быть заполнен ""Срок использования для вычисления амортизации"".';pl = 'Dla środka trwałego ""%FixedAsset%"" podanego w wierszu %LineNumber% listy ""Środki trwałe"" należy wpisać ""Liczba miesięcy do obliczenia amortyzacji"".';es_ES = 'Para el activo fijo ""%FixedAsset%"" indicado en la línea %LineNumber% de la lista ""Activos fijos"" tiene que rellenarse con la ""Vida útil para calcular la depreciación"".';es_CO = 'Para el activo fijo ""%FixedAsset%"" indicado en la línea %LineNumber% de la lista ""Activos fijos"" tiene que rellenarse con la ""Vida útil para calcular la depreciación"".';tr = '""Sabit kıymetler"" listesinin %LineNumber% satırında gösterilen ""%FixedAsset%"" sabit kıymeti için ""Amortismanın hesaplanması için yararlı ömür"" doldurulmalıdır.';it = 'Per il cespite ""%FixedAsset%"" indicato nella stringa %LineNumber% del elenco ""Cespiti"" deve essere compilato con la ""Vita utile per calcolare l''ammortamento"".';de = 'Für das Anlagevermögen ist ""%FixedAsset%"" in der Zeichenkette %LineNumber% der Liste ""Anlagevermögen"" mit ""Nutzungsdauer zur Berechnung der Abschreibungen"" zu füllen.'");
			MessageText = StrReplace(MessageText, "%FixedAsset%", TrimAll(String(RowOfFixedAssets.FixedAsset))); 
			MessageText = StrReplace(MessageText, "%LineNumber%",String(RowOfFixedAssets.LineNumber));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"FixedAssets",
				RowOfFixedAssets.LineNumber,
				"UsagePeriodForDepreciationCalculation",
				Cancel
			);
		EndIf;
			
		If RowOfFixedAssets.FixedAsset.DepreciationMethod = Enums.FixedAssetDepreciationMethods.ProportionallyToProductsVolume
		   AND RowOfFixedAssets.AmountOfProductsServicesForDepreciationCalculation = 0 Then
			MessageText = NStr("en = 'For fixed asset ""%FixedAsset%"" indicated in string %LineNumber% of list ""Fixed assets"" should be filled with ""Product (work) volume to calculate depreciation in physical units."".'; ru = 'Для основного средства ""%FixedAsset%"" указанного в строке %LineNumber% списка ""Основные средства"", должен быть заполнен ""Объем продукции (работ) для исчисления амортизации в натуральных единицах"".';pl = 'Dla środka trwałego ""%FixedAsset%"" wskazanego w wierszu %LineNumber% listy ""Środki trwałe"" należy wypełnić pole ""Ilość towarów (zakres prac) do obliczenia amortyzacji w jednostkach fizycznych"".';es_ES = 'Para el activo fijo ""%FixedAsset%"" indicado en la línea %LineNumber% de la lista ""Activos fijos"" tiene que rellenarse con el ""Volumen de productos (trabajos) para calcular la depreciación en unidades físicas."".';es_CO = 'Para el activo fijo ""%FixedAsset%"" indicado en la línea %LineNumber% de la lista ""Activos fijos"" tiene que rellenarse con el ""Volumen de productos (trabajos) para calcular la depreciación en unidades físicas."".';tr = '""Sabit kıymetler"" listesinin %LineNumber% dizesinde gösterilen ""%FixedAsset%"" sabit kıymetleri için ""Amortismanın fiziksel birimler cinsinden hesaplanması için ürün (çalışma) hacmi"" ile doldurulmalıdır.';it = 'Per il cespite ""%FixedAsset%"" indicato nella riga %LineNumber% dell''elenco ""Cespiti"" dovrebbe essere compilato con ""Volume del prodotto (lavoro)  per il calcolo degli ammortamenti in termini fisici."".';de = 'Für das Anlagevermögen ""%FixedAsset%"", das in der Zeichenkette %LineNumber% der Liste ""Anlagevermögen"" angegeben ist, ist mit ""Produkt- (Arbeits-)volumen zur Berechnung der Abschreibungen in physischen Einheiten"" zu füllen.'");
			MessageText = StrReplace(MessageText, "%FixedAsset%", TrimAll(String(RowOfFixedAssets.FixedAsset))); 
			MessageText = StrReplace(MessageText, "%LineNumber%",String(RowOfFixedAssets.LineNumber));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"FixedAssets",
				RowOfFixedAssets.LineNumber,
				"AmountOfProductsServicesForDepreciationCalculation",
				Cancel
			);
		EndIf;
		
		If RowOfFixedAssets.RegisterExpense And Not ValueIsFilled(RowOfFixedAssets.ExpenseItem) Then
			DriveServer.ShowMessageAboutError(
					ThisObject,
					StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'On the Fixed assets tab, in line #%1, an expense item is required.'; ru = 'На вкладке ""Основные средства"" в строке %1 требуется указать статью расходов.';pl = 'Na karcie Środki trwałe, w wierszu nr %1, pozycja rozchodów jest wymagana.';es_ES = 'En la pestaña Activos fijos, en la línea #%1, se requiere un artículo de gastos.';es_CO = 'En la pestaña Activos fijos, en la línea #%1, se requiere un artículo de gastos.';tr = 'Sabit kıymetler sekmesinin %1 nolu satırında gider kalemi gerekli.';it = 'Nella scheda Cespiti fissi, nella riga #%1, è richiesta una voce di uscita.';de = 'Eine Position von Ausgaben ist in der Zeile Nr. %1 auf der Registerkarte Anlagevermögen erforderlich.'"),
						RowOfFixedAssets.LineNumber),
					"FixedAssets",
					RowOfFixedAssets.LineNumber,
					"ExpenseItem",
					Cancel);
		EndIf;
		
	EndDo;
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Accounting templates properties initialization.
	AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(Ref, AdditionalProperties, Cancel);
	If AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
		Return;
	EndIf;
	
	// Initialization of document data
	Documents.FixedAssetRecognition.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectFixedAssetStatuses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectFixedAssetParameters(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectFixedAssets(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	
	// Accounting
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingEntriesData(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Creating control of negative balances.
	Documents.FixedAssetRecognition.RunControl(Ref, AdditionalProperties, Cancel);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.Posting, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
		
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties to undo document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Creating control of negative balances.
	Documents.FixedAssetRecognition.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.UndoPosting, DeletionMark, Company, Date, AdditionalProperties);
			
		DriveServer.ReflectDeletionAccountingTransactionDocuments(Ref);
		
	EndIf;
		
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DriveServer.CheckDocumentsReposting(Ref, AdditionalProperties.Posted, Cancel);
	
	If Not Cancel And AdditionalProperties.WriteMode = DocumentWriteMode.Write Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, AdditionalProperties.WriteMode, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
		
EndProcedure

#EndRegion

#EndIf