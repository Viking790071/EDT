
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	StatesContainer = New Structure;
	StatesContainer.Insert("SearchState", FullTextSearchServer.FullTextSearchState());
	// Possible values:
	// SearchAllowed
	// UpdatingIndex
	// IndexMergeInProgress
	// IndexUpdateRequired
	// SearchSettingsError
	// SearchProhibited
	StatesContainer.Insert("SearchInSections", False);
	StatesContainer.Insert("SearchAreas", New ValueList); // Metadata objects IDs.
	StatesContainer.Insert("CurrentPosition", 0);
	StatesContainer.Insert("Count", 0);
	StatesContainer.Insert("TotalCount", 0);
	StatesContainer.Insert("ErrorCode", "");
	// Possible values:
	// SearchError
	// TooManyResults
	// FoundNothing
	StatesContainer.Insert("ErrorDescription", "");
	StatesContainer.Insert("SearchResults", New Array); // See ExecuteFullTextSearch. 
	StatesContainer.Insert("SearchHistory", New Array); // List of search phrases.
	
	LoadSettingsAndSearchHistory(StatesContainer);
	
	If Not IsBlankString(Parameters.PassedSearchString) Then
		SearchString = Parameters.PassedSearchString;
		OnExecuteSearchAtServer(StatesContainer, SearchString);
	EndIf;
	
	RefreshSearchHistory(Items.SearchString, StatesContainer);
	SearchAreasPresentation = SearchAreaPresentation(StatesContainer);
	UpdateNavigationButtonsAvailability(Items.Next, Items.Previous, StatesContainer);
	FoundItemsInformationPresentation = PresentationOfInformationOnFound(StatesContainer);
	HTMLPagePresentation = HTMLPagePresentation(SearchString, StatesContainer);
	SearchStatePresentation = SearchStatePresentation(StatesContainer);
	UpdateVisibilitySearchState(StatesContainer);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure SearchStringChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	// Workaround for the platform error.
#If WebClient Then
	If Items.SearchString.ChoiceList.Count() = 1 Then
		ValueSelected = Item.EditText;
	EndIf;
#EndIf
	
	SearchString = ValueSelected;
	OnExecuteSearch("FirstPart");
	
EndProcedure

&AtClient
Procedure SearchAreasPresentationClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	SearchAreas   = StatesContainer.SearchAreas;
	SearchInSections = StatesContainer.SearchInSections;
	
	OpeningParameters = New Structure;
	OpeningParameters.Insert("SearchAreas",   SearchAreas);
	OpeningParameters.Insert("SearchInSections", SearchInSections);
	
	Notification = New NotifyDescription("AfterGetSearchAreaSettings", ThisObject);
	
	OpenForm("DataProcessor.FullTextSearchInData.Form.SearchAreaChoice",
		OpeningParameters,,,,, Notification);
	
EndProcedure

&AtClient
Procedure HTMLTextOnClick(Item, EventData, StandardProcessing)
	
	StandardProcessing = False;
	
	HTMLRef = EventData.Anchor;
	
	If HTMLRef = Undefined Then
		Return;
	EndIf;
	
	Notification = New NotifyDescription("AfterOpenURL", ThisObject);
	CommonClient.OpenURL(HTMLRef.href, Notification);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure RunSearch(Command)
	
	OnExecuteSearch("FirstPart");
	
EndProcedure

&AtClient
Procedure Previous(Command)
	
	OnExecuteSearch("PreviousPart");
	
EndProcedure

&AtClient
Procedure Next(Command)
	
	OnExecuteSearch("NextPart");
	
EndProcedure

#EndRegion

#Region Private

#Region PrivateEventHandlers

&AtClient
Procedure AfterGetSearchAreaSettings(Result, AdditionalParameters) Export
	
	If TypeOf(Result) = Type("Structure") Then
		OnSetSearchArea(Result);
	EndIf;
	
EndProcedure

&AtServer
Procedure OnSetSearchArea(SearchAreaSettings)
	
	SaveSearchSettings(SearchAreaSettings.SearchInSections, SearchAreaSettings.SearchAreas);
	
	FillPropertyValues(StatesContainer, SearchAreaSettings,
		"SearchAreas, SearchInSections");
	
	SearchAreasPresentation = SearchAreaPresentation(StatesContainer);
	
EndProcedure

&AtClient
Procedure OnExecuteSearch(SearchDirection)
	
	If IsBlankString(SearchString) Then
		ShowMessageBox(, NStr("ru = '??????????????, ?????? ?????????? ??????????'; en = 'Enter a search item'; pl = 'Wpisz, co nale??y znale????';es_ES = 'Introducir un objeto de b??squeda';es_CO = 'Introducir un objeto de b??squeda';tr = 'Bulunmas?? gerekeni girin';it = 'Inserire un elemento di ricerca';de = 'Geben Sie hier ein, was Sie finden m??ssen'"));
		Return;
	EndIf;
	
	If CommonInternalClient.IsURL(SearchString) Then
		CommonClient.OpenURL(SearchString);
		SearchString = "";
		Return;
	EndIf;
	
	OnExecuteSearchAtServer(StatesContainer, SearchString, SearchDirection);
	
	AttachIdleHandler("AfterExecuteSearch", 0.1, True);
	
EndProcedure

&AtServerNoContext
Procedure OnExecuteSearchAtServer(StatesContainer, SearchString, SearchDirection = "FirstPart")
	
	SaveSearchStringToHistory(SearchString, StatesContainer.SearchHistory);
	
	SearchParameters = FullTextSearchServer.SearchParameters();
	FillPropertyValues(SearchParameters, StatesContainer,
		"CurrentPosition, SearchInSections, SearchAreas");
	SearchParameters.SearchString = SearchString;
	SearchParameters.SearchDirection = SearchDirection;
	
	SearchResult = FullTextSearchServer.ExecuteFullTextSearch(SearchParameters);
	
	FillPropertyValues(StatesContainer, SearchResult, 
		"CurrentPosition, Count, TotalCount, ErrorCode, ErrorDescription, SearchResults");
	
	StatesContainer.SearchState = FullTextSearchServer.FullTextSearchState();
	
EndProcedure

&AtClient
Procedure AfterExecuteSearch()
	
	RefreshSearchHistory(Items.SearchString, StatesContainer);
	UpdateNavigationButtonsAvailability(Items.Next, Items.Previous, StatesContainer);
	FoundItemsInformationPresentation = PresentationOfInformationOnFound(StatesContainer);
	HTMLPagePresentation = HTMLPagePresentation(SearchString, StatesContainer);
	SearchStatePresentation = SearchStatePresentation(StatesContainer);
	UpdateVisibilitySearchState(StatesContainer);
	
EndProcedure

&AtClient
Procedure AfterOpenURL(ApplicationStarted, Context) Export
	
	If Not ApplicationStarted Then 
		ShowMessageBox(, NStr("ru = '???????????????? ???????????????? ?????????????? ???????? ???? ??????????????????????????'; en = 'Objects of this type cannot be opened'; pl = 'Otwarcie obiekt??w tego typu nie jest przewidziano';es_ES = 'No est?? prevista la apertura de los objetos de este tipo';es_CO = 'No est?? prevista la apertura de los objetos de este tipo';tr = 'Bu t??r nesneler a????lmaz';it = 'Gli oggetti di questo tipo non possono essere aperti';de = 'Das ??ffnen von Objekten dieses Typs ist nicht vorgesehen'"));
	EndIf;
	
EndProcedure

#EndRegion

#Region Presentations

&AtClientAtServerNoContext
Procedure RefreshSearchHistory(Item, StatesContainer)
	
	SearchHistory = StatesContainer.SearchHistory;
	
	If TypeOf(SearchHistory) = Type("Array") Then
		Item.ChoiceList.LoadValues(SearchHistory);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function SearchAreaPresentation(StatesContainer)
	
	SearchInSections = StatesContainer.SearchInSections;
	SearchAreas   = StatesContainer.SearchAreas;
	
	SearchAreasSpecified = SearchAreas.Count() > 0;
	
	If Not SearchInSections Or Not SearchAreasSpecified Then
		Return NStr("ru = '??????????'; en = 'Everywhere'; pl = 'Wsz??dzie';es_ES = 'En todos lados';es_CO = 'En todos lados';tr = 'Her yere';it = 'Ovunque';de = '??berall'");
	EndIf;
	
	If SearchAreas.Count() < 5 Then
		SearchAreaPresentation = "";
		For each Area In SearchAreas Do
			MetadataObject = Common.MetadataObjectByID(Area.Value);
			SearchAreaPresentation = SearchAreaPresentation + ListFormPresentation(MetadataObject) + ", ";
		EndDo;
		Return Left(SearchAreaPresentation, StrLen(SearchAreaPresentation) - 2);
	EndIf;
	
	Return NStr("ru = '?? ?????????????????? ????????????????'; en = 'In selected sections'; pl = 'W wybranych rozdzia??ach';es_ES = 'En los apartados seleccionados';es_CO = 'En los apartados seleccionados';tr = 'Se??ilmi?? b??l??mlerde';it = 'Nelle sezioni selezionate';de = 'In den ausgew??hlten Abschnitten'");
	
EndFunction

&AtServerNoContext
Function ListFormPresentation(MetadataObject)
	
	If Not IsBlankString(MetadataObject.ExtendedListPresentation) Then
		Presentation = MetadataObject.ExtendedListPresentation;
	ElsIf Not IsBlankString(MetadataObject.ListPresentation) Then
		Presentation = MetadataObject.ListPresentation;
	Else 
		Presentation = MetadataObject.Presentation();
	EndIf;
	
	Return Presentation;
	
EndFunction

&AtClientAtServerNoContext
Procedure UpdateNavigationButtonsAvailability(NextButtonItem, PreviousButtonItem, StatesContainer)
	
	Count = StatesContainer.Count;
	
	If Count = 0 Then
		NextButtonItem.Enabled  = False;
		PreviousButtonItem.Enabled = False;
	Else
		
		TotalCount = StatesContainer.TotalCount;
		CurrentPosition   = StatesContainer.CurrentPosition;
		
		NextButtonItem.Enabled  = (TotalCount - CurrentPosition) > Count;
		PreviousButtonItem.Enabled = (CurrentPosition > 0);
		
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function PresentationOfInformationOnFound(StatesContainer)
	
	Count = StatesContainer.Count;
	
	If Count <> 0 Then
		
		CurrentPosition   = StatesContainer.CurrentPosition;
		TotalCount = StatesContainer.TotalCount;
		
		Return StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '???????????????? %1 - %2 ???? %3'; en = 'Shown %1 - %2 out of %3'; pl = 'Jest pokazany %1 - %2 z %3';es_ES = 'Mostrado %1 - %2 de %3';es_CO = 'Mostrado %1 - %2 de %3';tr = 'G??sterilen %1 - %2''den %3';it = 'Mostrato %1 - %2 su %3';de = 'Gezeigt %1 - %2 aus %3'"),
			Format(CurrentPosition + 1, "NZ=0; NG="),
			Format(CurrentPosition + Count, "NZ=0; NG="),
			Format(TotalCount, "NZ=0; NG="));
			
	EndIf;
	
	Return "";
	
EndFunction

&AtClientAtServerNoContext
Function HTMLPagePresentation(SearchString, StatesContainer)
	
	ErrorCode  = StatesContainer.ErrorCode;
	
	If IsBlankString(ErrorCode) Then 
		HTMLPage = NewHTMLResultPage(StatesContainer);
	Else 
		HTMLPage = NewHTMLErrorPage(StatesContainer);
	EndIf;
	
	Return HTMLPage;
	
EndFunction

&AtClientAtServerNoContext
Function NewHTMLResultPage(StatesContainer)
	
	PageTemplate = 
		"<html>
		|<head>
		|  <meta http-equiv=""Content-Type"" content=""text/html; charset=UTF-8"">
		|  <style type=""text/css"">
		|    html {
		|      overflow: auto;
		|    }
		|    body {
		|      margin: 10px;
		|      font-family: Arial, sans-serif;
		|      font-size: 10pt;
		|      overflow: auto;
		|      position: absolute;
		|      top: 0;
		|      left: 0;
		|      bottom: 0;
		|      right: 0;
		|    }
		|    div.main {
		|      overflow: auto;
		|      height: 100%;
		|    }
		|    div.presentation {
		|      font-size: 11pt;
		|    }
		|    div.textPortion {
		|      padding-bottom: 16px;
		|    }
		|    span.bold {
		|      font-weight: bold;
		|    }
		|    ol li {
		|      color: #B3B3B3;
		|    }
		|    ol li div {
		|      color: #333333;
		|    }
		|    a {
		|      text-decoration: none;
		|      color: #0066CC;
		|    }
		|    a:hover {
		|      text-decoration: underline;
		|    }
		|    .gray {
		|      color: #B3B3B3;
		|    }
		|  </style>
		|</head>
		|<body>
		|  <div class=""main"">
		|    <ol start=""%CurrentPosition%"">
		|%Rows%
		|    </ol>
		|  </div>
		|</body>
		|</html>";
	
	StringPattern = 
		"      <li>
		|        <div class=""presentation""><a href=""%Ref%"">%Presentation%</a></div>
		|        %HTMLDetails%
		|      </li>";
	
	InactiveStringPattern = 
		"      <li>
		|        <div class=""presentation""><a href=""#"" class=""gray"">%Presentation%</a></div>
		|        %HTMLDetails%
		|      </li>";
	
	SearchResults = StatesContainer.SearchResults;
	CurrentPosition   = StatesContainer.CurrentPosition;
	
	Rows = "";
	
	For each SearchResultString In SearchResults Do 
		
		Ref        = SearchResultString.Ref;
		Presentation = SearchResultString.Presentation;
		HTMLDetails  = SearchResultString.HTMLDetails;
		
		If Ref = "#" Then 
			Row = InactiveStringPattern;
		Else 
			Row = StrReplace(StringPattern, "%Ref%", Ref);
		EndIf;
		
		Row = StrReplace(Row, "%Presentation%", Presentation);
		Row = StrReplace(Row, "%HTMLDetails%",  HTMLDetails);
		
		Rows = Rows + Row;
		
	EndDo;
	
	HTMLPage = StrReplace(PageTemplate, "%Rows%", Rows);
	HTMLPage = StrReplace(HTMLPage  , "%CurrentPosition%", CurrentPosition + 1);
	
	Return HTMLPage;
	
EndFunction

&AtClientAtServerNoContext
Function NewHTMLErrorPage(StatesContainer)
	
	PageTemplate = 
		"<html>
		|<head>
		|  <meta http-equiv=""Content-Type"" content=""text/html; charset=UTF-8"">
		|  <style type=""text/css"">
		|    html { 
		|      overflow:auto;
		|    }
		|    body {
		|      margin: 10px;
		|      font-family: Arial, sans-serif;
		|      font-size: 10pt;
		|      overflow: auto;
		|      position: absolute;
		|      top: 0;
		|      left: 0;
		|      bottom: 0;
		|      right: 0;
		|    }
		|    div.main {
		|      overflow: auto;
		|      height: 100%;
		|    }
		|    div.error {
		|      font-size: 12pt;
		|    }
		|    div.presentation {
		|      font-size: 11pt;
		|    }
		|    h3 {
		|      color: #009646
		|    }
		|    li {
		|      padding-bottom: 16px;
		|    }
		|    a {
		|      text-decoration: none;
		|      color: #0066CC;
		|    }
		|    a:hover {
		|      text-decoration: underline;
		|    }
		|  </style>
		|</head>
		|<body>
		|  <div class=""main"">
		|    <div class=""error"">%1</div>
		|    <p>%2</p>
		|  </div>
		|</body>
		|</html>";
	
	HTMLRecommendations = 
		NStr("ru = '<h3>????????????????????????:</h3>
			|<ul>
			|  %SearchAreaRecommendation%
			|  %QueryTextRecommendation%
			|  <li>
			|    <b>???????????????????????????? ?????????????? ???? ???????????? ??????????.</b><br>
			|    ?????????????????????? ?????????????????? (*) ?? ???????????????? ??????????????????.<br>
			|    ????????????????, ?????????? ????????* ???????????? ?????? ??????????????????, ?????????????? ???????????????? ??????????, ???????????????????????? ???? ???????? - 
			|    ???????????? ""?????????????????????????? ?? ????????????"", ""?????? ??????????????????????????"" ??.??.??.
			|  </li>
			|  <li>
			|    <b>???????????????????????????? ???????????????? ??????????????.</b><br>
			|    ?????????????????????? ?????????????? (#).<br>
			|    ????????????????, ??????????????#2 ???????????? ?????? ??????????????????, ???????????????????? ?????????? ??????????, ?????????????? ???????????????????? ???? ?????????? 
			|    ?????????????? ???? ???????? ?????? ?????? ??????????.
			|  </li>
			|</ul>
			|<div class ""presentation""><a href=""v8help://1cv8/QueryLanguageFullTextSearchInData"">???????????? ???????????????? ?????????????? ?????????????????? ??????????????????</a></div>'; 
			|en = '<h3>Recommended:</h3>
			|<ul>
			|  %SearchAreaRecommendation%
			|  %QueryTextRecommendation%
			|  <li>
			|    <b>Search by beginning of a word.</b><br>
			|    Use an asterisk (*) at the end.<br>
			|    For example, a search for cons* will find all documents containing words that start with the same letters: 
			|    ""Construction and Repair"" magazine, ""Construction Works, Ltd.,"" and so on.
			|  </li>
			|  <li>
			|    <b>Use fuzzy search.</b><br>
			|    Use the number sign (#).<br>
			|    For example, a search for Camomile#2 will find all documents containing words that differ from the word 
			|    Camomile by one or two letters.
			|  </li>
			|</ul>
			|<div class ""presentation""><a href=""v8help://1cv8/QueryLanguageFullTextSearchInData"">Full description of search expressions format</a></div>'; 
			|pl = '<h3>Rekomendacje:</h3>
			|<ul>
			|  %SearchAreaRecommendation%
			|  %QueryTextRecommendation%
			|  <li>
			|    <b>Szukaj wed??ug pocz??tku s??owa.</b><br>
			|    U??ywaj gwiazdki (*) na ko??cu.<br>
			|    Na przyk??ad, bud* znajdzie wszystkie dokumenty, zawieraj??ce pocz??tek z tymi samymi literami: 
			|    czasopismo ""Budowa i naprawa"", ""Prace budownicze, Sp. z o.o.,"" itd.
			|  </li>
			|  <li>
			|    <b>U??yj wyszukiwania rozmytego.</b><br>
			|    U??ywaj znaku liczbowego (#).<br>
			|    Na przyk??ad, wyszukiwanie dla Rumianek#2 znajdzie wszystkie dokumenty, zawieraj??ce s??owa kt??re r????ni?? si?? od tego s??owa 
			|    o jedn?? lub o dwie litery.
			|  </li>
			|</ul>
			|<div class ""presentation""><a href=""v8help://1cv8/QueryLanguageFullTextSearchInData"">Pe??ny opis formatu wyra??e?? wyszukiwania</a></div>';
			|es_ES = '<h3>Recomensaciones:</h3>
			|<ul>
			|  %SearchAreaRecommendation%
			|  %QueryTextRecommendation%
			|  <li>
			|    <b>Utilice la b??squeda por el inicio de la palabra.</b><br>
			|    Utilice el asterisco (*) para terminar.<br>
			|    Por ejemplo, la consulta constr* encontrar?? todos los documentos, que contienen las palabras, que empiezan con constr - 
			|    Revista ""Construcci??n y obras"", ""SL ConstrCompleto"" etc
			|  </li>
			|  <li>
			|    <b>Utilice la b??squeda indefinida.</b><br>
			|    Utilice numeral (#).<br>
			|    Por ejemplo, Manzanilla#2 encontrar?? todos los documentos, que contienen estas palabras, que se diferencian de la palabra 
			|    Manzanilla en una o dos letras.
			|  </li>
			|</ul>
			|<div class ""presentation""><a href=""v8help://1cv8/QueryLanguageFullTextSearchInData"">Descripci??n completa del formato de las expresiones de b??squeda</a></div>';
			|es_CO = '<h3>Recomensaciones:</h3>
			|<ul>
			|  %SearchAreaRecommendation%
			|  %QueryTextRecommendation%
			|  <li>
			|    <b>Utilice la b??squeda por el inicio de la palabra.</b><br>
			|    Utilice el asterisco (*) para terminar.<br>
			|    Por ejemplo, la consulta constr* encontrar?? todos los documentos, que contienen las palabras, que empiezan con constr - 
			|    Revista ""Construcci??n y obras"", ""SL ConstrCompleto"" etc
			|  </li>
			|  <li>
			|    <b>Utilice la b??squeda indefinida.</b><br>
			|    Utilice numeral (#).<br>
			|    Por ejemplo, Manzanilla#2 encontrar?? todos los documentos, que contienen estas palabras, que se diferencian de la palabra 
			|    Manzanilla en una o dos letras.
			|  </li>
			|</ul>
			|<div class ""presentation""><a href=""v8help://1cv8/QueryLanguageFullTextSearchInData"">Descripci??n completa del formato de las expresiones de b??squeda</a></div>';
			|tr = '<h3>??neriler:</h3>
			|<ul>
			|%SearchAreaRecommendation%
			|%QueryTextRecommendation%
			| <li>
			|  <b>Kelimenin ba????na g??re aray??n.</b><br>
			|   Kelimenin sonu olarak (*) kullan??n.<br>
			|  ??rne??in, sat* olarak yap??lan arama, sat- ile ba??layan t??m kelimeleri bulacakt??r - 
			|   ""??n??aat ve onar??m"" dergisi, ""OOO StroyKomplekt"" vs.
			|</li>
			|  <li>
			|    <b>Bulan??k aramay?? kullan??n.</b><br>
			|    (#) kullan??n.<br>
			|   ??rne??in, Papatya#2 , Papatya kelimesinden bir veya iki harf fark?? olan t??m kelimeleri bulur.
			|
			|  </li>
			|</ul>
			|<div class ""presentation""><a href=""v8help://1cv8/QueryLanguageFullTextSearchInData"">Arama ifade bi??iminin tam a????klamas??</a></div>';
			|it = '<h3>Consigliato:</h3>
			|<ul>
			|  %SearchAreaRecommendation%
			|  %QueryTextRecommendation%
			|  <li>
			|    <b>Ricerca per inizio della parola.</b><br>
			|    Utilizza un asterisco (*) alla fine.<br>
			|    Per esempio, un ricerca per costr* trover?? tutti i documenti contenenti parole che incominciano con le stesse lettere: 
			|    ""Costruzuone e riparazione"" Rivista, ""Costruttori associati, Srl.,"" e cosi via.
			|  </li>
			|  <li>
			|    <b>Utilizzare ricerca Fuzzy.</b><br>
			|    Use the number sign (#).<br>
			|    Per esempio cercando per Camomilla#2 will find all documents containing words that differ from the wordtrover?? tutti i documenti che differeiscono dalla parol
			|    Camomilla per una o due lettere.
			|  </li>
			|</ul>
			|<div class ""presentation""><a href=""v8help://1cv8/QueryLanguageFullTextSearchInData"">Descrizione completa del formato delle espressioni di ricerca</a></div>';
			|de = '<h3>Empfehlungen:</h3>
			|<ul>
			|%SearchAreaRecommendation%
			|%QueryTextRecommendation%
			|  <li>
			|<b>Verwenden Sie die Suche am Wortanfang.</b><br>
			| Benutze Sternchen (*) als Endung.<br>
			|  Zum Beispiel findet eine Suche nach einer Bau* alle Dokumente, die W??rter enthalten, die mit dem Wort Bau beginnen -
			|  Journal ""Bau und Renovierung"", ""BauKomplekt GmbH"", etc.
			|  </li>
			|  <li>
			|   <b>Verwenden Sie die unscharfe Suche.</b><br>
			|   Verwenden Sie das Gitter (#).<br>
			|   Zum Beispiel findet Kamille#2 alle Dokumente, die W??rter enthalten, die sich vom Wort
			| Kamille um ein oder zwei Buchstaben unterscheiden.
			|  </li>
			|</ul>
			|<div class ""presentation""><a href=""v8help://1cv8/QueryLanguageFullTextSearchInData""> Vollst??ndige Beschreibung des Suchbegriffsformats</a></div>'");
	
	ErrorDescription  = StatesContainer.ErrorDescription;
	ErrorCode       = StatesContainer.ErrorCode;
	SearchInSections = StatesContainer.SearchInSections;
	SearchAreas   = StatesContainer.SearchAreas;
	
	SearchAreasSpecified = SearchAreas.Count() > 0;
	
	SearchAreaRecommendationHTML = "";
	QueryTextRecommendationHTML = "";
	
	If ErrorCode = "FoundNothing" Then 
		
		If SearchInSections AND SearchAreasSpecified Then 
		
			SearchAreaRecommendationHTML = 
				NStr("ru = '<li><b>???????????????? ?????????????? ????????????.</b><br>
					|???????????????????? ?????????????? ???????????? ???????????????? ???????????? ?????? ?????? ??????????????.</li>'; 
					|en = '<li><b>Refine a search area.</b><br>
					|Try to select more search areas or all sections.</li>'; 
					|pl = '<li><b>U??ci??lij obszar wyszukiwania.</b><br>
					|Spr??buj wybra?? wi??cej obszar??w wyszukiwania lub wszystkie sekcje.</li>';
					|es_ES = '<li><b>Especifique el ??rea de la b??squeda.</b><br>
					|Intente seleccionar m??s ??reas de b??squeda o todos los apartados.</li>';
					|es_CO = '<li><b>Especifique el ??rea de la b??squeda.</b><br>
					|Intente seleccionar m??s ??reas de b??squeda o todos los apartados.</li>';
					|tr = '<li><b>Arama alan??n?? netle??tirin.</b><br>
					|Daha fazla arama alan?? veya t??m b??l??mleri se??meyi deneyin.</li>';
					|it = '<li><b>Rifinire l''area di ricerca.</b><br>
					|Prova a selezionare pi?? aree di ricerca o tutte le sezioni.</li>';
					|de = '<li><b>Verfeinern Sie Ihren Suchbereich.</b><br>
					|Versuchen Sie, mehr Suchbereiche oder alle Abschnitte auszuw??hlen.</li>'");
		EndIf;
		
		QueryTextRecommendationHTML =
			NStr("ru = '<li><b>?????????????????? ????????????, ???????????????? ???? ???????? ??????????-???????? ??????????.</b></li>'; en = '<li><b>Refine the search text by excluding a word from it.</b></li>'; pl = '<li><b>U??ci??lij tekst wyszukiwania wykluczaj??c z niego s??owo.</b></li>';es_ES = '<li><b>Especifique la consulta, excluyendo de ella alguna palabra.</b></li>';es_CO = '<li><b>Especifique la consulta, excluyendo de ella alguna palabra.</b></li>';tr = '<li><b>Herhangi bir kelimeyi hari?? tutarak sorguyu basitle??tirin.</b></li>';it = '<li><b>Rifinire il testo di ricerca escludendo una parola da esso.</b></li>';de = '<li><b>Vereinfachen Sie die Suche, indem Sie ein Wort davon ausschlie??en.</b></li>'");
		
	ElsIf ErrorCode = "TooManyResults" Then
		
		If Not SearchInSections Or Not SearchAreasSpecified Then 
			
			SearchAreaRecommendationHTML = 
			NStr("ru = '<li><b>???????????????? ?????????????? ????????????.</b><br>
				|???????????????????? ?????????????? ?????????????? ????????????, ?????????? ???????????? ???????????? ?????? ????????????.</li>'; 
				|en = '<li><b>Refine a search area.</b><br>
				|Try to select a search area by setting a specific area or list.</li>'; 
				|pl = '<li><b>U??ci??lij obszar wyszukiwania.</b><br>
				|Spr??buj wybra?? obszar wyszukiwania za pomoc?? ustawienia okre??lonego obszaru lub listy.</li>';
				|es_ES = '<li><b>Especifique la consulta, excluyendo de ella alguna palabra.</b><br>
				|Intente seleccionar el ??rea de b??squeda habiendo especificado un apartado exacto o una lista.</li>';
				|es_CO = '<li><b>Especifique la consulta, excluyendo de ella alguna palabra.</b><br>
				|Intente seleccionar el ??rea de b??squeda habiendo especificado un apartado exacto o una lista.</li>';
				|tr = '<li><b>Arama alan??n?? netle??tirin.</b><br>
				|Tam bir b??l??m veya liste belirterek bir arama alan?? se??meyi deneyin.</li>';
				|it = '<li><b>Rifinire l''area di ricerca.</b><br>
				|Prova a selezionare un''area di ricerca impostando una area specifica o elenco.</li>';
				|de = '<li><b>Geben Sie den Suchbereich an.</b><br>
				|Versuchen Sie, einen Suchbereich auszuw??hlen, indem Sie den genauen Abschnitt oder die Liste angeben.</li>'");
		EndIf;
		
	EndIf;
	
	HTMLRecommendations = StrReplace(HTMLRecommendations, "%SearchAreaRecommendation%", SearchAreaRecommendationHTML);
	HTMLRecommendations = StrReplace(HTMLRecommendations, "%QueryTextRecommendation%", QueryTextRecommendationHTML);
	
	Return StringFunctionsClientServer.SubstituteParametersToString(PageTemplate, ErrorDescription, HTMLRecommendations);
	
EndFunction

&AtClientAtServerNoContext
Function SearchStatePresentation(StatesContainer)
	
	SearchState = StatesContainer.SearchState;
	
	If SearchState = "SearchAllowed" Then 
		Presentation = "";
	ElsIf SearchState = "IndexUpdateInProgress"
		Or SearchState = "IndexMergeInProgress"
		Or SearchState = "IndexUpdateRequired" Then 
		
		Presentation = NStr("ru = '???????????????????? ???????????? ?????????? ???????? ??????????????????, ?????????????????? ?????????? ??????????????.'; en = 'Search results might be inaccurate. Try your search again later.'; pl = 'Wyniki wyszukiwania mog?? by?? niedok??adne, powt??rz wyszukiwanie p????niej.';es_ES = 'Los resultados de la b??squeda no pueden ser precisos, vuelva a buscar m??s tarde.';es_CO = 'Los resultados de la b??squeda no pueden ser precisos, vuelva a buscar m??s tarde.';tr = 'Arama sonu??lar?? yanl???? olabilir, daha sonra aramay?? tekrarlay??n.';it = 'I risultati della ricerca potrebbero essere imprecisi, ripetere la ricerca in un secondo momento.';de = 'Die Suchergebnisse k??nnen ungenau sein, wiederholen Sie die Suche sp??ter.'");
	ElsIf SearchState = "SearchSettingsError" Then 
		
		// For non-administrator
		Presentation = NStr("ru = '???????????????????????????? ?????????? ???? ????????????????, ???????????????????? ?? ????????????????????????????.'; en = 'Full-text search is not configured. Contact your administrator.'; pl = 'Wyszukiwanie pe??notekstowe nie jest ustawione, zwr???? si?? do administratora.';es_ES = 'La b??squeda de texto completo no est?? ajustado, dir??jase al administrador.';es_CO = 'La b??squeda de texto completo no est?? ajustado, dir??jase al administrador.';tr = 'Tam metin aramas?? yap??land??r??lmam????t??r, y??neticinize ba??vurun.';it = 'La ricerca full-text non ?? configurata. Contattare l''amministratore.';de = 'Die Volltextsuche ist nicht konfiguriert, bitte wenden Sie sich an den Administrator.'");
		
	ElsIf SearchState = "SearchProhibited" Then 
		Presentation = NStr("ru = '???????????????????????????? ?????????? ????????????????.'; en = 'Full-text search is disabled.'; pl = 'Wyszukiwanie pe??notekstowe jest wy????czone.';es_ES = 'B??squeda de texto completo est?? desactivada.';es_CO = 'B??squeda de texto completo est?? desactivada.';tr = 'Tam metin aramas?? devre d??????.';it = 'Ricerca a testo integrale ?? disabilitato';de = 'Volltextsuche deaktiviert.'");
	EndIf;
	
	Return Presentation;
	
EndFunction

&AtServer
Procedure UpdateVisibilitySearchState(StatesContainer)
	
	SearchState = StatesContainer.SearchState;
	Items.SearchState.Visible = (SearchState <> "SearchAllowed");
	
EndProcedure

#EndRegion

#Region BusinessLogic

&AtServerNoContext
Procedure LoadSettingsAndSearchHistory(SearchSettings)
	
	SearchHistory = Common.CommonSettingsStorageLoad("FullTextSearchFullTextSearchStrings", "");
	SavedSearchSettings = Common.CommonSettingsStorageLoad("FullTextSearchSettings", "");
	
	SearchInSections = Undefined;
	SearchAreas   = Undefined;
	
	If TypeOf(SavedSearchSettings) = Type("Structure") Then
		SavedSearchSettings.Property("SearchInSections", SearchInSections);
		SavedSearchSettings.Property("SearchAreas",   SearchAreas);
	EndIf;
	
	SearchSettings.SearchInSections = ?(SearchInSections = Undefined, False, SearchInSections);
	SearchSettings.SearchAreas   = ?(SearchAreas = Undefined, New ValueList, SearchAreas);
	SearchSettings.SearchHistory   = ?(SearchHistory = Undefined, New Array, SearchHistory);
	
EndProcedure

&AtServerNoContext
Procedure SaveSearchStringToHistory(SearchString, SearchHistory)
	
	SavedString = SearchHistory.Find(SearchString);
	
	If SavedString <> Undefined Then
		SearchHistory.Delete(SavedString);
	EndIf;
	
	SearchHistory.Insert(0, SearchString);
	
	StringsCount = SearchHistory.Count();
	
	If StringsCount > 20 Then
		SearchHistory.Delete(StringsCount - 1);
	EndIf;
	
	Common.CommonSettingsStorageSave(
		"FullTextSearchFullTextSearchStrings",
		"",
		SearchHistory);
	
EndProcedure

&AtServerNoContext
Procedure SaveSearchSettings(SearchInSections, SearchAreas)
	
	Settings = New Structure;
	Settings.Insert("SearchInSections", SearchInSections);
	Settings.Insert("SearchAreas",   SearchAreas);
	
	Common.CommonSettingsStorageSave("FullTextSearchSettings", "", Settings);
	
EndProcedure

#EndRegion

#EndRegion
