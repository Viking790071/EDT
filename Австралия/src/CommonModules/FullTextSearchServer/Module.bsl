#Region Public

// Updates a full-text search index.
Procedure FullTextSearchIndexUpdate() Export
	
	UpdateIndex(NStr("ru = 'Обновление индекса ППД'; en = 'Update full text search index'; pl = 'Aktualizacja indeksu wyszukiwania pełnotekstowego';es_ES = 'Actualizar el índice de la búsqueda del texto completo';es_CO = 'Actualizar el índice de la búsqueda del texto completo';tr = 'Tam metin arama dizinini güncelle';it = 'Aggiorna l''indice di ricerca full-text';de = 'Aktualisieren Sie den Volltextsuchindex'"), False, True);
	
EndProcedure

// Merges full-text search indexes.
Procedure FullTextSearchMergeIndex() Export
	
	UpdateIndex(NStr("ru = 'Слияние индекса ППД'; en = 'Merge full text search index'; pl = 'Łączenie indeksu wyszukiwania pełnotekstowego.';es_ES = 'Combinando el índice de la búsqueda del texto completo.';es_CO = 'Combinando el índice de la búsqueda del texto completo.';tr = 'Tam metin arama dizinini birleştir';it = 'Unisci l''indice di ricerca full-text';de = 'Zusammenführen des Volltextsuchindex'"), True);
	
EndProcedure

// Returns a flag showing whether full-text search index is up-to-date.
//   The UseFullTextSearch functional option is checked in the calling code.
//
// Returns:
//   Boolean - True - full-text search contains relevant data.
//
Function SearchIndexIsRelevant() Export
	
	Return (
		// Operations are not allowed, or the index fully complies with the current infobase state, or the 
		// index was updated less than 5 minutes ago.
		// 
		Not OperationsAllowed()
		Or FullTextSearch.IndexTrue()
		Or CurrentDate() < (FullTextSearch.UpdateDate() + 300)); // Exception from the CurrentSessionDate() rule.
	
EndFunction

#EndRegion

#Region Internal

// Returns a flag showing whether full-text search operations (index update, index clearing, and search) are allowed.
Function OperationsAllowed() Export
	
	Return (FullTextSearch.GetFullTextSearchMode() = FullTextSearchMode.Enable);
	
EndFunction

Function UseFullTextSearch() Export
	
	Return Metadata.FunctionalOptions.UseFullTextSearch;
	
EndFunction

#Region ConfigurationSubsystemsEventHandlers

// See ToDoListOverridable.OnDetermineToDoListHandlers. 
Procedure OnFillToDoList(ToDoList) Export
	
	ModuleToDoListServer = Common.CommonModule("ToDoListServer");
	If Not Users.IsFullUser(, True)
		Or Not GetFunctionalOption("UseFullTextSearch")
		Or ModuleToDoListServer.UserTaskDisabled("FullTextSearchInData") Then
		Return;
	EndIf;
	
	IndexUpdateDate = FullTextSearch.UpdateDate();
	CurrentDate = CurrentDate(); // Exception, use CurrentDate().
	If IndexUpdateDate > CurrentDate Then
		Interval = NStr("ru = 'менее одного дня'; en = 'less than a day'; pl = 'mniej niż jeden dzień';es_ES = 'menos de un día';es_CO = 'menos de un día';tr = 'bir günden az';it = 'Medo di un giorno';de = 'weniger als ein Tag'");
	Else
		Interval = Common.TimeIntervalString(IndexUpdateDate, CurrentDate);
	EndIf;
	DaysFromLastUpdate = Int((CurrentDate - IndexUpdateDate) / 60 / 60 / 24);
	
	Section = Metadata.Subsystems.Find("Administration");
	If Section <> Undefined Then
		Sections = New Array;
		Sections.Add(Section);
	Else
		Sections = ModuleToDoListServer.SectionsForObject(Metadata.DataProcessors.FullTextSearchInData.FullName());
	EndIf;
	
	For each Section In Sections Do
		IDFullTextSearch = "FullTextSearchInData" + StrReplace(Section.FullName(), ".", "");
		UserTask = ToDoList.Add();
		UserTask.ID  = IDFullTextSearch;
		UserTask.HasUserTasks       = (DaysFromLastUpdate >= 1 AND Not FullTextSearch.IndexTrue());
		UserTask.Presentation  = NStr("ru = 'Индекс полнотекстового поиска устарел'; en = 'Full-text search index is obsolete'; pl = 'Indeks wyszukiwania pełnotekstowego jest nieaktualny';es_ES = 'Índice de la búsqueda de texto completo está desactualizada';es_CO = 'Índice de la búsqueda de texto completo está desactualizada';tr = 'Tam metin arama dizini eskidi';it = 'L''indice di ricerca full-text è obsoleto.';de = 'Der Volltextsuchindex ist veraltet'");
		UserTask.Form          = "DataProcessor.FullTextSearchInData.Form.FullTextSearchAndTextExtractionControl";
		UserTask.ToolTip      = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Последнее обновление %1 назад'; en = 'Last update was %1 ago'; pl = 'Ostatnia aktualizacja miała miejsce %1 temu';es_ES = 'Última actualización se ha hecho hace %1';es_CO = 'Última actualización se ha hecho hace %1';tr = 'Son güncelleme %1önceydi';it = 'Ultimo aggiornamento su %1 indietro';de = 'Letzte Aktualisierung war vor %1'"), Interval);
		UserTask.Owner       = Section;
	EndDo;
	
EndProcedure

// See InfobaseUpdateSSL.OnAddUpdateHandlers. 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.InitialFilling = True;
	Handler.Procedure = "FullTextSearchServer.InitializeFullTextSearchFunctionalOption";
	Handler.Version = "1.0.0.1";
	Handler.SharedData = True;
	
EndProcedure

// See ScheduledJobsOverridable.OnDefineScheduledJobSettings. 
Procedure OnDefineScheduledJobSettings(Dependencies) Export
	
	Dependence = Dependencies.Add();
	Dependence.ScheduledJob = Metadata.ScheduledJobs.FullTextSearchIndexUpdate;
	Dependence.FunctionalOption = Metadata.FunctionalOptions.UseFullTextSearch;
	
	Dependence = Dependencies.Add();
	Dependence.ScheduledJob = Metadata.ScheduledJobs.FullTextSearchMergeIndex;
	Dependence.FunctionalOption = Metadata.FunctionalOptions.UseFullTextSearch;
	
EndProcedure

#EndRegion

// Sets a value of the UseFullTextSearch constant.
//   Used to synchronize a value of the UseFullTextSearch functional option
//   
//   with the FullTextSearch.GetFullTextSearchMode() function value.
//
Procedure InitializeFullTextSearchFunctionalOption() Export
	
	ConstantValue = OperationsAllowed();
	Constants.UseFullTextSearch.Set(ConstantValue);
	
EndProcedure

#EndRegion

#Region Private

#Region ScheduledJobsHandlers

// Handler of the FullTextSearchUpdateIndex scheduled job.
Procedure FullTextSearchUpdateIndexOnSchedule() Export
	
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.FullTextSearchIndexUpdate);
	
	If MergeIndexBackgroundJobInProgress() Then
		Return;
	EndIf;
	
	FullTextSearchIndexUpdate();
	
EndProcedure

// Handler of the FullTextSearchMergeIndex scheduled job.
Procedure FullTextSearchMergeIndexOnSchedule() Export
	
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.FullTextSearchMergeIndex);
	
	If IndexUpdateBackgroundJobInProgress() Then
		Return;
	EndIf;
	
	FullTextSearchMergeIndex();
	
EndProcedure

#EndRegion

#Region SearchBusinessLogic

#Region SearchState

Function FullTextSearchState() Export
	
	If GetFunctionalOption("UseFullTextSearch") Then 
		
		If FullTextSearch.GetFullTextSearchMode() = FullTextSearchMode.Enable Then 
			
			// Exception from the CurrentSessionDate() rule.
			If CurrentDate() < (FullTextSearch.UpdateDate() + 300) Then 
				Return "SearchAllowed";
			Else
				If FullTextSearch.IndexTrue() Then 
					Return "SearchAllowed";
				ElsIf IndexUpdateBackgroundJobInProgress() Then 
					Return "IndexUpdateInProgress";
				ElsIf MergeIndexBackgroundJobInProgress() Then 
					Return "IndexMergeInProgress";
				Else
					Return "IndexUpdateRequired";
				EndIf;
			EndIf;
			
		Else 
			// The value of the UseFullTextSearch constant is not synchronized with the full-text search mode 
			// set in the infobase.
			Return "SearchSettingsError";
		EndIf;
		
	Else
		If FullTextSearch.GetFullTextSearchMode() = FullTextSearchMode.Enable Then
			// The value of the UseFullTextSearch constant is not synchronized with the full-text search mode 
			// set in the infobase.
			Return "SearchSettingsError";
		Else 
			Return "SearchProhibited";
		EndIf;
	EndIf;
	
EndFunction

Function IndexUpdateBackgroundJobInProgress()
	
	ScheduledJob = Metadata.ScheduledJobs.FullTextSearchIndexUpdate;
	
	Filter = New Structure;
	Filter.Insert("MethodName", ScheduledJob.MethodName);
	Filter.Insert("State", BackgroundJobState.Active);
	CurrentBackgroundJobs = BackgroundJobs.GetBackgroundJobs(Filter);
	
	Return CurrentBackgroundJobs.Count() > 0;
	
EndFunction

Function MergeIndexBackgroundJobInProgress()
	
	ScheduledJob = Metadata.ScheduledJobs.FullTextSearchMergeIndex;
	
	Filter = New Structure;
	Filter.Insert("MethodName", ScheduledJob.MethodName);
	Filter.Insert("State", BackgroundJobState.Active);
	CurrentBackgroundJobs = BackgroundJobs.GetBackgroundJobs(Filter);
	
	Return CurrentBackgroundJobs.Count() > 0;
	
EndFunction

#EndRegion

#Region PerformSearch

Function SearchParameters() Export 
	
	Parameters = New Structure;
	Parameters.Insert("SearchString", "");
	Parameters.Insert("SearchDirection", "FirstPart");
	Parameters.Insert("CurrentPosition", 0);
	Parameters.Insert("SearchInSections", False);
	Parameters.Insert("SearchAreas", New Array);
	
	Return Parameters;
	
EndFunction

Function ExecuteFullTextSearch(SearchParameters) Export 
	
	SearchString    = SearchParameters.SearchString;
	Direction     = SearchParameters.SearchDirection;
	CurrentPosition  = SearchParameters.CurrentPosition;
	SearchInSections = SearchParameters.SearchInSections;
	SearchAreas   = SearchParameters.SearchAreas;
	
	BatchSize = 10;
	ErrorDescription = "";
	ErrorCode = "";
	
	SearchList = FullTextSearch.CreateList(SearchString, BatchSize);
	
	If SearchInSections AND SearchAreas.Count() > 0 Then
		SearchList.MetadataUse = FullTextSearchMetadataUse.DontUse;
		
		For each Area In SearchAreas Do
			MetadataObject = Common.MetadataObjectByID(Area.Value);
			SearchList.SearchArea.Add(MetadataObject);
		EndDo;
	EndIf;
	
	Try
		If Direction = "FirstPart" Then
			SearchList.FirstPart();
		ElsIf Direction = "PreviousPart" Then
			SearchList.PreviousPart(CurrentPosition);
		ElsIf Direction = "NextPart" Then
			SearchList.NextPart(CurrentPosition);
		Else 
			Raise NStr("ru = 'Параметр SearchDirection задан неверно.'; en = 'Invalid SearchDirection parameter.'; pl = 'Parametr SearchDirection jest podany błędnie.';es_ES = 'Parámetro SearchDirection está especificado incorrectamente.';es_CO = 'Parámetro SearchDirection está especificado incorrectamente.';tr = 'SearchDirection parametresi yanlış girilmiştir.';it = 'Parametro SearchDirection parameter non valido.';de = 'Der Parameter SuchRichtung ist nicht korrekt eingestellt.'");
		EndIf;
	Except
		ErrorDescription = BriefErrorDescription(ErrorInfo());
		ErrorCode = "SearchError";
	EndTry;
	
	If SearchList.TooManyResults() Then 
		ErrorDescription = NStr("ru = 'Слишком много результатов, уточните запрос'; en = 'Too many results, refine your search'; pl = 'Zbyt dużo wyników, uściślij zapytanie';es_ES = 'Hay demasiados resultados, refinar los criterios de su búsqueda';es_CO = 'Hay demasiados resultados, refinar los criterios de su búsqueda';tr = 'Çok fazla sonuç var, aramanızı netleştirin';it = 'Troppi risultati, affinate la vostra ricerca';de = 'Zu viele Ergebnisse, verfeinern Sie die Anfrage'");
		ErrorCode = "TooManyResults";
	EndIf;
	
	TotalCount = SearchList.TotalCount();
	
	If TotalCount = 0 Then
		ErrorDescription = NStr("ru = 'По запросу ничего не найдено'; en = 'No results found'; pl = 'Brak rezultatów wyszukiwania';es_ES = 'No hay resultados encontrados';es_CO = 'No hay resultados encontrados';tr = 'Sonuç bulunamadı';it = 'Nessun risultato trovato';de = 'Keine Ergebnisse gefunden'");
		ErrorCode = "FoundNothing";
	EndIf;
	
	If IsBlankString(ErrorCode) Then 
		SearchResults = FullTextSearchResults(SearchList);
	Else 
		SearchResults = New Array;
	EndIf;
	
	Result = New Structure;
	Result.Insert("CurrentPosition", SearchList.StartPosition());
	Result.Insert("Count", SearchList.Count());
	Result.Insert("TotalCount", TotalCount);
	Result.Insert("ErrorCode", ErrorCode);
	Result.Insert("ErrorDescription", ErrorDescription);
	Result.Insert("SearchResults", SearchResults);
	
	Return Result;
	
EndFunction

Function FullTextSearchResults(SearchList)
	
	// Parse the list by separating an HTML details block.
	HTMLSearchStrings = HTMLSearchResultStrings(SearchList);
	
	Result = New Array;
	
	// Bypass search list strings.
	For Index = 0 To SearchList.Count() - 1 Do
		
		HTMLDetails  = HTMLSearchStrings.HTMLDetails.Get(Index);
		Presentation = HTMLSearchStrings.Presentations.Get(Index);
		SearchListString = SearchList.Get(Index);
		
		ObjectMetadata = SearchListString.Metadata;
		Value          = SearchListString.Value;
		
		Overridable_OnGetByFullTextSearch(ObjectMetadata, Value, Presentation);
		
		Ref = "";
		Try
			Ref = GetURL(Value);
		Except
			Ref = "#"; // It is not to be opened.
		EndTry;
		
		ResultString = New Structure;
		ResultString.Insert("Ref",        Ref);
		ResultString.Insert("HTMLDetails",  HTMLDetails);
		ResultString.Insert("Presentation", Presentation);
		
		Result.Add(ResultString);
		
	EndDo;
	
	Return Result;
	
EndFunction

Function HTMLSearchResultStrings(SearchList)
	
	HTMLListDisplay = SearchList.GetRepresentation(FullTextSearchRepresentationType.HTMLText);
	
	// Get DOM to display the list.
	// You cannot make this function as a separate function for getting DOM due to a platform error occurred in the call stack of the DOM reader stream.
	HTMLReader = New HTMLReader;
	HTMLReader.SetString(HTMLListDisplay);
	DOMBuilder = New DOMBuilder;
	DOMListDisplay = DOMBuilder.Read(HTMLReader);
	HTMLReader.Close();
	
	DivDOMItemsList = DOMListDisplay.GetElementByTagName("div");
	HTMLDetailsStrings = HTMLDetailsStrings(DivDOMItemsList);
	
	AnchorDOMItemsList = DOMListDisplay.GetElementByTagName("a");
	PresentationStrings = PresentationStrings(AnchorDOMItemsList);
	
	Result = New Structure;
	Result.Insert("HTMLDetails", HTMLDetailsStrings);
	Result.Insert("Presentations", PresentationStrings);
	
	Return Result;
	
EndFunction

Function HTMLDetailsStrings(DivDOMItemsList)
	
	HTMLDetailsStrings = New Array;
	For each DOMItem In DivDOMItemsList Do 
		
		If DOMItem.ClassName = "textPortion" Then 
			
			DOMWriter = New DOMWriter;
			HTMLWriter = New HTMLWriter;
			HTMLWriter.SetString();
			DOMWriter.Write(DOMItem, HTMLWriter);
			
			HTMLResultStringDetails = HTMLWriter.Close();
			
			HTMLDetailsStrings.Add(HTMLResultStringDetails);
			
		EndIf;
	EndDo;
	
	Return HTMLDetailsStrings;
	
EndFunction

Function PresentationStrings(AnchorDOMItemsList)
	
	PresentationStrings = New Array;
	For each DOMItem In AnchorDOMItemsList Do
		
		Presentation = DOMItem.TextContent;
		PresentationStrings.Add(Presentation);
		
	EndDo;
	
	Return PresentationStrings;
	
EndFunction

// Allows to override:
// - Value
// - Presentation
//
// See the FullTextSearchListItem data type.
//
Procedure Overridable_OnGetByFullTextSearch(ObjectMetadata, Value, Presentation)
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then 
		
		// To get additional info, open the form of the object the value belongs to and not the form of the 
		// record in the information register.
		
		If ObjectMetadata = Metadata.InformationRegisters["AdditionalInfo"] Then 
			
			Value = Value.Object;
			
			ObjectMetadata = Value.Metadata();
			
			Presentation = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1: %2'; en = '%1: %2'; pl = '%1: %2';es_ES = '%1: %2';es_CO = '%1: %2';tr = '%1: %2';it = '%1: %2';de = '%1: %2'"), 
				ObjectMetadata.ObjectPresentation, String(Value));
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region SearchIndexUpdate

// Common procedure for updating and merging a full-text search index.
Procedure UpdateIndex(ProcedurePresentation, EnableJoining = False, InPortions = False)
	
	If NOT OperationsAllowed() Then
		Return;
	EndIf;
	
	Common.OnStartExecuteScheduledJob();
	
	LogRecord(Undefined, NStr("ru = 'Запуск процедуры ""%1"".'; en = 'Starting %1.'; pl = 'Rozpocząć procedurę ""%1"".';es_ES = 'Iniciar el procedimiento ""%1"".';es_CO = 'Iniciar el procedimiento ""%1"".';tr = '""%1"" Prosedürünü başlatın.';it = 'Inizio %1.';de = 'Starten Sie das ""%1"" Verfahren.'"), , ProcedurePresentation);
	
	Try
		FullTextSearch.UpdateIndex(EnableJoining, InPortions);
		LogRecord(Undefined, NStr("ru = 'Успешное завершение процедуры ""%1"".'; en = '%1 is successfully completed.'; pl = 'Procedura ""%1"" zakończona pomyślnie.';es_ES = 'El procedimiento ""%1"" se ha finalizado con éxito.';es_CO = 'El procedimiento ""%1"" se ha finalizado con éxito.';tr = '""%1"" prosedürü başarı ile tamamlandı.';it = '%1 è stato completato con successo.';de = 'Die Prozedur ""%1"" wurde erfolgreich abgeschlossen.'"), , ProcedurePresentation);
	Except
		LogRecord(Undefined, NStr("ru = 'Ошибка выполнения процедуры ""%1"":'; en = 'An error occurred when running %1:'; pl = 'Podczas wykonywania procedury ""%1"" wystąpił błąd:';es_ES = 'Ha ocurrido un error el ejecutar el procedimiento ""%1"":';es_CO = 'Ha ocurrido un error el ejecutar el procedimiento ""%1"":';tr = '""%1"" işlemı hatası:';it = 'Un errore si è registrato durante l''esecuzione di %1:';de = 'Beim Ausführen der Prozedur ""%1"" ist ein Fehler aufgetreten:'"), ErrorInfo(), ProcedurePresentation);
	EndTry;
	
EndProcedure

// Creates a record in the event log and in messages to a user.
//
// Parameters:
//   LogLevel - EventLogLevel - message importance for the administrator.
//   CommentWithParameters - String - a comment that can contain parameters %1.
//   ErrorInfo - ErrorInfo, String - error information placed after the comment.
//   Parameter - String - replaces %1 in CommentWithParameters.
//
Procedure LogRecord(LogLevel, CommentWithParameters, ErrorInformation = Undefined, 
	Parameter = Undefined)
	
	// Determine the event log level based on the type of the passed error message.
	If TypeOf(LogLevel) <> Type("EventLogLevel") Then
		If TypeOf(ErrorInformation) = Type("ErrorInfo") Then
			LogLevel = EventLogLevel.Error;
		ElsIf TypeOf(ErrorInformation) = Type("String") Then
			LogLevel = EventLogLevel.Warning;
		Else
			LogLevel = EventLogLevel.Information;
		EndIf;
	EndIf;
	
	// Comment for the event log.
	TextForLog = CommentWithParameters;
	If Parameter <> Undefined Then
		TextForLog = StringFunctionsClientServer.SubstituteParametersToString(TextForLog, Parameter);
	EndIf;
	If TypeOf(ErrorInformation) = Type("ErrorInfo") Then
		TextForLog = TextForLog + Chars.LF + DetailErrorDescription(ErrorInformation);
	ElsIf TypeOf(ErrorInformation) = Type("String") Then
		TextForLog = TextForLog + Chars.LF + ErrorInformation;
	EndIf;
	TextForLog = TrimAll(TextForLog);
	
	// Record to the event log.
	WriteLogEvent(
		NStr("ru = 'Полнотекстовое индексирование'; en = 'Full-text indexing'; pl = 'Indeksacja pełnotekstowa';es_ES = 'Indexación de texto completo';es_CO = 'Indexación de texto completo';tr = 'Tam metin indeksleme';it = 'indicizzazione full-text';de = 'Volltextindizierung'", CommonClientServer.DefaultLanguageCode()), 
		LogLevel, , , 
		TextForLog);
	
EndProcedure

#EndRegion

#EndRegion

#EndRegion
