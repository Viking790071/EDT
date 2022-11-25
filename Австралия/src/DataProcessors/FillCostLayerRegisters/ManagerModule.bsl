#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure Posting(Parameters, StorageAddress = "") Export
	
	SetPrivilegedMode(True);
	
	WriteLogEvent(
		NStr("en = 'FIFO.Posting documents'; ru = 'FIFO.Проведение документов';pl = 'FIFO.Dekretowanie dokumentów';es_ES = 'FIFO.Enviando los documentos';es_CO = 'FIFO.Enviando los documentos';tr = 'FIFO. Belgeleri gönderme';it = 'Pubblicazione documenti FIFO';de = 'FIFO. Buchungsbelege'", CommonClientServer.DefaultLanguageCode()),
		EventLogLevel.Information,
		,
		NStr("en = 'Start posting documents'; ru = 'Начало проведения документов';pl = 'Zacznij dekretowanie dokumentów';es_ES = 'Iniciar el envío de documentos';es_CO = 'Iniciar el envío de documentos';tr = 'Belge göndermeye başla';it = 'Avviare la pubblicazione documenti';de = 'Buchung von Dokumenten starten'"),
		EventLogEntryTransactionMode.Transactional);
		
	SourceRegisters = New Array;
	SourceRegisters.Add(Metadata.AccumulationRegisters.Inventory);
	SourceRegisters.Add(Metadata.AccumulationRegisters.LandedCosts);
	
	DocumentsForPosting = New Array();
	
	OnlyProduction = Parameters.Get("OnlyProduction");
	If OnlyProduction <> True Then
		CostLayerTypes = Metadata.DefinedTypes.CostLayer.Type.Types();
		For Each DocumentType In CostLayerTypes Do
			DocumentRef = New(DocumentType);
			DocumentsForPosting.Add(DocumentRef.Metadata());
		EndDo;
	// begin Drive.FullVersion
	Else
		DocumentsForPosting.Add(Metadata.Documents.Manufacturing);
		DocumentsForPosting.Add(Metadata.Documents.ManufacturingOperation);
		DocumentsForPosting.Add(Metadata.Documents.Production);
	// end Drive.FullVersion
	EndIf;
	
	
	DocumentsPeriod = DocumentsPeriod(SourceRegisters);
	
	If DocumentsPeriod.BeginPeriod = Undefined Then
		Parameters.Insert("LoadingIsCompleted", False);
		Parameters.Insert("MessageText", NStr("en = 'There are no documents for posting'; ru = 'Нет документов, которые нужно провести';pl = 'Brak dokumentów do dekretowania';es_ES = 'No hay documentos para enviar';es_CO = 'No hay documentos para enviar';tr = 'Gönderilecek belge yok';it = 'Non ci sono documenti per la pubblicazione';de = 'Es gibt keine Belege für Buchung'"));
	Else
		CurrentMonth = DocumentsPeriod.BeginPeriod;
		If ValueIsFilled(DocumentsPeriod.EndPeriod) Then
			While CurrentMonth < DocumentsPeriod.EndPeriod Do
				
				EndOfCurrentMonth = EndOfMonth(CurrentMonth);
				
				PostDocuments(DocumentsForPosting, CurrentMonth, EndOfCurrentMonth);
				
				CurrentMonth = AddMonth(CurrentMonth, 1);
				
			EndDo;
		EndIf;
		Parameters.Insert("LoadingIsCompleted", True);
	EndIf;
	
	If ValueIsFilled(StorageAddress) Then
		PutToTempStorage(Parameters, StorageAddress);
	EndIf;
EndProcedure
	
#EndRegion

#Region Private

Function DocumentsPeriod(SourceRegisters)
	
	QueryTextTemplate = "
	|SELECT ALLOWED
	|	MIN(Table.Period) AS BeginPeriod,
	|	MAX(Table.Period) AS EndPeriod
	|FROM
	|	&RegisterName AS Table";
	
	Query = New Query;
	DocumentsPeriod = New Structure("BeginPeriod, EndPeriod", Undefined, Undefined);
	
	For Each SourceRegister In SourceRegisters Do
		
		Query.Text = StrReplace(QueryTextTemplate, "&RegisterName", "AccumulationRegister." + SourceRegister.Name);
		Selection = Query.Execute().Select();
		Selection.Next();
		
		If DocumentsPeriod.BeginPeriod = Undefined Then
			FillPropertyValues(DocumentsPeriod, Selection);
		Else
			If ValueIsFilled(Selection.BeginPeriod)
				And Selection.BeginPeriod < DocumentsPeriod.BeginPeriod Then
				DocumentsPeriod.BeginPeriod = BegOfMonth(Selection.BeginPeriod);
			EndIf;
			If ValueIsFilled(Selection.EndPeriod)
				And Selection.EndPeriod > DocumentsPeriod.EndPeriod Then
				DocumentsPeriod.EndPeriod = EndOfMonth(Selection.EndPeriod) + 1;
			EndIf;
		EndIf;
	EndDo;
	
	Return DocumentsPeriod;
EndFunction

Procedure PostDocuments(Documents, BeginOfMonth, EndOfMonth)
	
	QueryTextTemplate = "
	|SELECT ALLOWED
	|	Doc.Ref AS Ref,
	|	Doc.Date AS Data,
	|	Doc.Company AS Company
	|FROM
	|	&DocumentName AS Doc
	|WHERE
	|	Doc.Date BETWEEN &BegOfPeriod AND &EndOfPeriod
	|	AND Doc.Posted";
	
	Query = New Query;
	Query.SetParameter("BegOfPeriod", BeginOfMonth);
	Query.SetParameter("EndOfPeriod", EndOfMonth);
	
	Companies = New Array;
	CostLayerRegisters = CostLayerRegisters();
	
	For Each Document In Documents Do
		
		Query.Text = StrReplace(QueryTextTemplate, "&DocumentName", "Document." + Document.Name);
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			Companies.Add(Selection.Company);
			WriteRecordsToRegister(Selection.Ref, CostLayerRegisters);
		EndDo;
		
	EndDo;
	
	Query.Text = 
	"SELECT ALLOWED
	|	Task.Month AS Month,
	|	Task.TaskNumber AS TaskNumber,
	|	Task.Company AS Company,
	|	Task.Document AS Document
	|INTO TempTasks
	|FROM
	|	InformationRegister.TasksForCostsCalculation AS Task
	|
	|UNION ALL
	|
	|SELECT
	|	&CurrentMonth,
	|	1,
	|	Companies.Ref,
	|	UNDEFINED
	|FROM
	|	Catalog.Companies AS Companies
	|WHERE
	|	Companies.Ref IN(&ArrayOfCompanies)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Task.Month AS Month,
	|	MIN(Task.TaskNumber) AS TaskNumber,
	|	Task.Company AS Company,
	|	Task.Document AS Document
	|FROM
	|	TempTasks AS Task
	|
	|GROUP BY
	|	Task.Month,
	|	Task.Company,
	|	Task.Document";
	
	Query.SetParameter("ArrayOfCompanies", Companies);
	Query.SetParameter("CurrentMonth", BeginOfMonth);
	Result = Query.Execute();
	
	Records = InformationRegisters.TasksForCostsCalculation.CreateRecordSet();
	Records.Load(Result.Unload());
	Records.Write();
	
EndProcedure

Function CostLayerRegisters()
	
	CostLayerRegisters = New Structure;
	CostLayerRegisters.Insert("TableInventoryCostLayer", AccumulationRegisters.InventoryCostLayer);
	CostLayerRegisters.Insert("TableLandedCosts", AccumulationRegisters.LandedCosts);
	CostLayerRegisters.Insert("TableInventory", AccumulationRegisters.Inventory);
	CostLayerRegisters.Insert("TableSales", AccumulationRegisters.Sales);
	CostLayerRegisters.Insert("TableAccountingJournalEntries", AccountingRegisters.AccountingJournalEntries);
	
	Return CostLayerRegisters;
EndFunction

Procedure WriteRecordsToRegister(Ref, RegistersForPosting)
	
	Var Table;
	
	BeginTransaction();
	
	Try
		
		AdditionalProperties = New Structure("IsNew, WriteMode", True, DocumentWriteMode.Posting);
		DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
		
		AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(Ref, AdditionalProperties, False);
		If AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
			
			RollbackTransaction();
			
			MessageText = NStr("en = 'Cannot post document ""%1"". 
				|The applicable Accounting transaction template is required.
				|Details: %2'; 
				|ru = 'Не удалось провести документ ""%1"". 
				|Требуется соответствующий шаблон бухгалтерских операций.
				|Подробнее: %2';
				|pl = 'Nie można zatwierdzić dokumentu ""%1"". 
				|Wymagany jest odpowiedni szablon transakcji księgowej.
				|Szczegóły: %2';
				|es_ES = 'No se ha podido contabilizar el documento ""%1"". 
				|Se requiere la plantilla de transacción contable aplicable. 
				|Detalles: ';
				|es_CO = 'No se ha podido contabilizar el documento ""%1"". 
				|Se requiere la plantilla de transacción contable aplicable. 
				|Detalles: ';
				|tr = '""%1"" belgesi kaydedilemiyor.
				|Uygulanabilir Muhasebe işlemi şablonu gerekli.
				|Ayrıntılar: %2';
				|it = 'Impossibile pubblicare il documento ""%1"". 
				|È richiesto il modello di transazione contabile applicabile.
				|Dettagli: %2';
				|de = 'Fehler beim Buchen des Dokuments ""%1"". 
				|Die verwendbare Buchhaltungstransaktionsvorlage ist erforderlich.
				|Details: %2'", CommonClientServer.DefaultLanguageCode());
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				MessageText,
				Ref,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
				NStr("en = 'FIFO preparation'; ru = 'Подготовка к переходу на FIFO.';pl = 'Przygotowanie FIFO';es_ES = 'Preparación de FIFO';es_CO = 'Preparación de FIFO';tr = 'FIFO hazırlığı';it = 'Preparazione FIFO';de = 'FIFO-Vorbereitung'", CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				,
				,
				ErrorDescription);
				
			Return;
			
		EndIf;
		
		Documents[AdditionalProperties.ForPosting.DocumentMetadata.Name].InitializeDocumentData(Ref, AdditionalProperties);
		
		Tables = AdditionalProperties.TableForRegisterRecords;
		
		For Each Register In RegistersForPosting Do
			If Tables.Property(Register.Key, Table) Then
				WriteRecords(Register.Value, Table, Ref);
			EndIf;
		EndDo;
		
		CommitTransaction();
		
	Except
		
		If TransactionActive() Then
			RollbackTransaction();
		EndIf;
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Error FIFO preparation : %2'; ru = 'Ошибка при подготовке к переходу на FIFO : %2';pl = 'Błąd przygotowania FIFO: %2';es_ES = 'Error de preparación de FIFO:%2';es_CO = 'Error de preparación de FIFO:%2';tr = 'FIFO hazırlığı hatası : %2';it = 'Errore preparazione FIFO : %2';de = 'Fehler FIFO Vorbereitung: %2'"),
			BriefErrorDescription(ErrorInfo()));
		
		WriteLogEvent(
			NStr("en = 'FIFO preparation'; ru = 'Подготовка к переходу на FIFO.';pl = 'Przygotowanie FIFO';es_ES = 'Preparación de FIFO';es_CO = 'Preparación de FIFO';tr = 'FIFO hazırlığı';it = 'Preparazione FIFO';de = 'FIFO-Vorbereitung'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,
			,
			,
			ErrorDescription);
			
	EndTry;
	
EndProcedure

Procedure WriteRecords(RegisterManager, Table, Ref)
	
	Records = RegisterManager.CreateRecordSet();
	Records.Filter.Recorder.Set(Ref);
	Records.Read();
	
	If Records.Count() > 0 Or Table.Count() > 0 Then
		Records.Load(Table);
		Records.Write(True);
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
