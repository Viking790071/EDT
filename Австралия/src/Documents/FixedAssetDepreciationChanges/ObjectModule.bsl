#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Executes preliminary control.
//
Procedure RunPreliminaryControl(Cancel)
	
	// Row duplicates.
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
			MessageText = NStr("en = 'The ""%FixedAsset%"" fixed asset in the %LineNumber% line of the ""Fixed assets"" list is duplicated.'; ru = 'Основное средство ""%FixedAsset%"" указанное в строке %LineNumber% списка ""Основные средства"", указано повторно.';pl = 'Środek trwały ""%FixedAsset%"" w wierszu %LineNumber% listy ""Środki trwałe"" jest zduplikowany.';es_ES = 'El activo fijo ""%FixedAsset%"" en la línea %LineNumber% de la lista de ""Activos fijos"" está duplicado.';es_CO = 'El activo fijo ""%FixedAsset%"" en la línea %LineNumber% de la lista de ""Activos fijos"" está duplicado.';tr = '""Sabit kıymetler"" listesinin %LineNumber% satırının ""%FixedAsset%"" sabit kıymeti kopyalanır.';it = 'Il cespiti""%FixedAsset%"" nella linea %LineNumber% dell''elenco ""Cespiti"" è duplicato.';de = 'Das ""%FixedAsset%"" Anlagevermögen in der %LineNumber%Zeile der Liste ""Anlagevermögen"" wird dupliziert.'");
			MessageText = StrReplace(MessageText, "%LineNumber%", QueryResultSelection.LineNumber);
			MessageText = StrReplace(MessageText, "%FixedAsset%", QueryResultSelection.FixedAsset);
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
	
	Query = New Query;
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	Query.SetParameter("Period", Date);
	Query.SetParameter("FixedAssetsList", FixedAssets.UnloadColumn("FixedAsset"));
	
	Query.Text =
	"SELECT ALLOWED
	|	FixedAssetStateSliceLast.FixedAsset AS FixedAsset
	|FROM
	|	InformationRegister.FixedAssetStatus.SliceLast(&Period, Company = &Company) AS FixedAssetStateSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	FixedAssetStateSliceLast.FixedAsset AS FixedAsset
	|FROM
	|	InformationRegister.FixedAssetStatus.SliceLast(
	|			&Period,
	|			Company = &Company
	|				AND FixedAsset IN (&FixedAssetsList)
	|				AND State = VALUE(Enum.FixedAssetStatus.AcceptedForAccounting)) AS FixedAssetStateSliceLast";
	
	ResultsArray = Query.ExecuteBatch();
	
	ArrayVAStatus = ResultsArray[0].Unload().UnloadColumn("FixedAsset");
	ArrayVAAcceptedForAccounting = ResultsArray[1].Unload().UnloadColumn("FixedAsset");
	
	For Each RowOfFixedAssets In FixedAssets Do
			
		If ArrayVAStatus.Find(RowOfFixedAssets.FixedAsset) = Undefined Then
			MessageText = NStr("en = 'Statuses are not registered for the %FixedAsset% fixed asset in the %LineNumber% line of the ""Fixed assets"" list.'; ru = 'Для основного средства ""%FixedAsset%"" указанного в строке %LineNumber% списка ""Основные средства"", не зарегистрированы состояния.';pl = 'Dla środka trwałego %FixedAsset% w wierszu %LineNumber% listy ""Środki trwałe"" nie zarejestrowano statusów.';es_ES = 'Estados no están registrado para el activo fijo %FixedAsset% en la línea %LineNumber% de la lista de ""Activos fijos"".';es_CO = 'Estados no están registrado para el activo fijo %FixedAsset% en la línea %LineNumber% de la lista de ""Activos fijos"".';tr = 'Durumlar ""Sabit kıymetler"" listesinin %LineNumber% satırının %FixedAsset% sabit kıymeti için kaydedilir.';it = 'Gli stati non sono registrati per il cespite %FixedAsset% nella linea %LineNumber% dell''elenco ""Cespiti"".';de = 'Für das %FixedAsset% Anlagevermögen werden in der %LineNumber% Zeile der Liste ""Anlagevermögen"" keine Status registriert.'");
			MessageText = StrReplace(MessageText, "%FixedAsset%", TrimAll(String(RowOfFixedAssets.FixedAsset))); 
			MessageText = StrReplace(MessageText, "%LineNumber%",String(RowOfFixedAssets.LineNumber));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"FixedAssets",
				RowOfFixedAssets.LineNumber,
				"FixedAsset",
				Cancel
			);
		ElsIf ArrayVAAcceptedForAccounting.Find(RowOfFixedAssets.FixedAsset) = Undefined Then
			MessageText = NStr("en = 'The current status of the %FixedAsset% fixed asset in line No. %LineNumber% of the ""Fixed assets"" list is ""Not recognized"".'; ru = 'Для основного средства ""%FixedAsset%"" указанного в строке %LineNumber% списка ""Основные средства"", текущее состояние ""Не принят к учету"".';pl = 'Bieżący status środka trwałego %FixedAsset% z wiersza nr %LineNumber% listy ""Środki trwałe"" to ""Nieprzyjęty"".';es_ES = 'El estado actual del activo fijo %FixedAsset% en la línea número %LineNumber% de la lista de ""Activos fijos"" es ""No reconocido"".';es_CO = 'El estado actual del activo fijo %FixedAsset% en la línea número %LineNumber% de la lista de ""Activos fijos"" es ""No reconocido"".';tr = '""Sabit kıymetler"" listesinin No. %LineNumber% satırındaki %FixedAsset% sabit kıymetinin o an ki durumu ""Tanınmadı"" şeklindedir.';it = 'Il currente stato del cespite %FixedAsset% nella linea No. %LineNumber% del elenco ""Cespiti"" è ""Non riconosciuto"".';de = 'Der aktuelle Status des %FixedAsset% Anlagevermögens in Zeile Nummer %LineNumber% der Auflistung ""Anlagevermögen"" ist ""Nicht erkannt"".'");
			MessageText = StrReplace(MessageText, "%FixedAsset%", TrimAll(String(RowOfFixedAssets.FixedAsset))); 
			MessageText = StrReplace(MessageText, "%LineNumber%",String(RowOfFixedAssets.LineNumber));
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

#EndRegion

#Region EventsHandlers

// Procedure of filling the document on the basis.
//
// Parameters:
// FillingData - Structure - Data on filling the document.
//	
Procedure FillByFixedAssets(FillingData)
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	DepreciationParametersSliceLast.FixedAsset AS FixedAsset,
	|	DepreciationParametersSliceLast.StructuralUnit AS Department,
	|	DepreciationParametersSliceLast.AmountOfProductsServicesForDepreciationCalculation AS AmountOfProductsServicesForDepreciationCalculation,
	|	DepreciationParametersSliceLast.CostForDepreciationCalculation AS CostForDepreciationCalculation,
	|	DepreciationParametersSliceLast.UsagePeriodForDepreciationCalculation AS UsagePeriodForDepreciationCalculation,
	|	&DepreciationCharge AS ExpenseItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DepreciationParametersSliceLast.GLExpenseAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLExpenseAccount,
	|	DepreciationParametersSliceLast.BusinessLine AS BusinessLine,
	|	DepreciationParametersSliceLast.Recorder.Company AS Company
	|FROM
	|	InformationRegister.FixedAssetParameters.SliceLast(, FixedAsset = &FixedAsset) AS DepreciationParametersSliceLast";
	
	Query.SetParameter("FixedAsset", FillingData);
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	Query.SetParameter("DepreciationCharge", Catalogs.DefaultIncomeAndExpenseItems.GetItem("DepreciationCharge"));
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		
		Company = Selection.Company;
		
		NewRow = FixedAssets.Add();
		FillPropertyValues(NewRow, Selection);
		
		NewRow.StructuralUnit = Selection.Department;
		NewRow.RegisterExpense = True;
		NewRow.RegisterRevaluation = True;
		
	EndIf;
	
EndProcedure

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
				
			Else
				
				RowFixedAssets.BusinessLine = Undefined;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(ThisObject, Cancel);
	// End Change of approved documents
	
	AdditionalProperties.Insert("Posted", Posted);
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	// Preliminary control execution.
	RunPreliminaryControl(Cancel);
	
	For Each RowOfFixedAssets In FixedAssets Do
			
		If RowOfFixedAssets.FixedAsset.DepreciationMethod = Enums.FixedAssetDepreciationMethods.Linear
		   AND RowOfFixedAssets.UsagePeriodForDepreciationCalculation = 0 Then
			MessageText = NStr("en = 'For fixed assets ""%FixedAsset%"" indicated in row No.%LineNumber% of the ""Fixed assets"" list, the ""Useful life to calculate depreciation"" should be filled.'; ru = 'Для основного средства ""%FixedAsset%"" указанного в строке %LineNumber% списка ""Основные средства"", должен быть заполнен ""Срок использования для вычисления амортизации"".';pl = 'Dla środków trwałych ""%FixedAsset%"" wskazanych w wierszu nr %LineNumber% listy ""Środki trwałe"" należy wypełnić pole ""Liczba miesięcy amortyzacji do obliczenia"".';es_ES = 'Para los activos fijos ""%FixedAsset%"" indicados en la fila número %LineNumber% de la lista de ""Activos fijos"", la ""Vida útil para calcular la depreciación"" tiene que estar rellenada.';es_CO = 'Para los activos fijos ""%FixedAsset%"" indicados en la fila número %LineNumber% de la lista de ""Activos fijos"", la ""Vida útil para calcular la depreciación"" tiene que estar rellenada.';tr = '""Sabit kıymetler"" listesinin %LineNumber% numaralı satırında gösterilen ""%FixedAsset%"" sabit kıymetleri için ""Amortismanın hesaplanması için yararlı ömür"" doldurulmalıdır.';it = 'Per i cespiti ""%FixedAsset%"" indicati nella riga No %LineNumber% dell''elenco ""Cespiti"", la ""Vita utile per il calcolo ammortamento"" dovrebbe essere compilata.';de = 'Für das Anlagevermögen ""%FixedAsset%"", das in der Zeile Nr.%LineNumber% der Liste ""Anlagevermögen"" angegeben ist, ist die ""Nutzungsdauer zur Berechnung der Abschreibungen"" anzugeben.'");
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
			MessageText = NStr("en = 'For fixed asset ""%FixedAsset%"" indicated in row No.%LineNumber% of the ""Fixed assets"" list, the ""Product (work) volume to calculate depreciation in physical units"" should be filled."".'; ru = 'Для основного средства ""%FixedAsset%"" указанного в строке %LineNumber% списка ""Основные средства"", должен быть заполнен ""Объем продукции (работ) для исчисления амортизации в натуральных единицах"".';pl = 'Dla środków trwałych ""%FixedAsset%"" wskazanych w wierszu nr %LineNumber% listy ""Środki trwałe"" należy wypełnić pole ""Ilość produkcji (zakres prac) do obliczenia amortyzacji w jednostkach fizycznych"".';es_ES = 'Para el activo fijo ""%FixedAsset%"" indicado en la fila número %LineNumber% de la lista de ""Activos fijos"", el ""Volumen de productos (trabajos) para calcular la depreciación en unidades físicas"" tiene que estar rellenado."".';es_CO = 'Para el activo fijo ""%FixedAsset%"" indicado en la fila número %LineNumber% de la lista de ""Activos fijos"", el ""Volumen de productos (trabajos) para calcular la depreciación en unidades físicas"" tiene que estar rellenado."".';tr = '""Sabit kıymetler"" listesinin No.%LineNumber% satırında gösterilen ""%FixedAsset%"" sabit kıymeti için, ""Fiziksel olarak amortisman hesaplaması için Ürün (iş) hacmi"" doldurulmalıdır.';it = 'Per i cespiti ""%FixedAsset%"" indicati nella riga.%LineNumber% dell''elenco ""Cespiti"", il campo ""Volume del prodotto (lavoro) per il calcolo dell''ammortamento in maniera fisica"" dovrebbe essere compilato."".';de = 'Für das Anlagevermögen ""%FixedAsset%"", das in Zeile Nr. %LineNumber% der Liste ""Anlagevermögen"" angegeben ist, ist das Feld ""Produkt-(Arbeits-)volumen zur Berechnung der Abschreibungen in physischen Einheiten"" zu füllen.'");
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
		
		If GetFunctionalOption("UseDefaultTypeOfAccounting")
			And RowOfFixedAssets.CostForDepreciationCalculation > RowOfFixedAssets.CostForDepreciationCalculationBeforeChanging Then
			CheckedAttributes.Add("FixedAssets.RevaluationAccount");
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
		
		If RowOfFixedAssets.RegisterRevaluation And Not ValueIsFilled(RowOfFixedAssets.RevaluationItem) Then
			DriveServer.ShowMessageAboutError(
				ThisObject,
				StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'On the Fixed assets tab, in line #%1, a revaluation item is required. '; ru = 'На вкладке ""Основные средства"" в строке %1 требуется указать статью переоценки. ';pl = 'Na karcie Środki trwałe, w wierszu nr %1, pozycja przeszacowania jest wymagana. ';es_ES = 'En la pestaña Activos fijos, en la línea #%1, se requiere un artículo de revalorización. ';es_CO = 'En la pestaña Activos fijos, en la línea #%1, se requiere un artículo de revalorización. ';tr = 'Sabit kıymetler sekmesinin %1 nolu satırında yeniden değerleme kalemi gerekli. ';it = 'Nella scheda Cespiti fissi, nella riga #%1, è richiesto un elemento di rivalutazione. ';de = 'Eine Position von Neubewertung ist in der Zeile Nr. %1 auf der Registerkarte Anlagevermögen erforderlich. '"),
					RowOfFixedAssets.LineNumber),
				"FixedAssets",
				RowOfFixedAssets.LineNumber,
				"RevaluationItem",
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
	Documents.FixedAssetDepreciationChanges.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectFixedAssetParameters(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectFixedAssets(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	
	// Accounting
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingEntriesData(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
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