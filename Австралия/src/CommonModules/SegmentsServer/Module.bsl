
#Region Public

// Procedure adds comparison kinds to the rule
//
// Parameters:
//  Rule					 - ValueTableRow - the
//  AddedComparisonTypes filled in rule - String - comparison kinds in
//  row, separator , DefaultKindNumber	 - Number - number of rule comparison that is also a default value
Procedure AddComparisonTypes(Rule, AddedComparisonsKinds, DefaultTypeNumber = 1) Export
	
	TypesArray = StringFunctionsClientServer.SplitStringIntoSubstringsArray(AddedComparisonsKinds, ",");
	
	For Each KindInString In TypesArray Do
		KindInString = TrimAll(KindInString);
		If KindInString = "Equal" Then
			Rule.AvailableComparisonTypes.Add(DataCompositionComparisonType.Equal,			NStr("en = 'Equal'; ru = 'равных';pl = 'Równy';es_ES = 'Igual';es_CO = 'Igual';tr = 'Eşit';it = 'uguale';de = 'Gleich'"));
		ElsIf KindInString = "NotEqual" Then
			Rule.AvailableComparisonTypes.Add(DataCompositionComparisonType.NotEqual,		NStr("en = 'Not equal'; ru = 'Не равно';pl = 'Nie równy';es_ES = 'Desigual';es_CO = 'Desigual';tr = 'Eşit değil';it = 'Non uguale';de = 'Nicht gleich'"));
		ElsIf KindInString = "Greater" Then
			Rule.AvailableComparisonTypes.Add(DataCompositionComparisonType.Greater,		NStr("en = 'Greater'; ru = 'Больше';pl = 'Większy';es_ES = 'Mayor';es_CO = 'Mayor';tr = 'Daha büyük';it = 'Maggiore';de = 'Größer'"));
		ElsIf KindInString = "GreaterOrEqual" Then
			Rule.AvailableComparisonTypes.Add(DataCompositionComparisonType.GreaterOrEqual,	NStr("en = 'More or equal'; ru = 'Больше или равно';pl = 'Większy lub równy';es_ES = 'Más o igual';es_CO = 'Más o igual';tr = 'Daha fazla veya eşit';it = 'Maggiore o uguale';de = 'Mehr oder gleichwertig'"));
		ElsIf KindInString = "Less" Then
			Rule.AvailableComparisonTypes.Add(DataCompositionComparisonType.Less,		 	NStr("en = 'Less'; ru = 'Меньше';pl = 'Mniejszy';es_ES = 'Menor';es_CO = 'Menor';tr = 'Daha az';it = 'Meno';de = 'Weniger'"));
		ElsIf KindInString = "LessOrEqual" Then
			Rule.AvailableComparisonTypes.Add(DataCompositionComparisonType.LessOrEqual, 	NStr("en = 'Less or equal'; ru = 'Меньше или равно';pl = 'Mniejszy lub równy';es_ES = 'Menor o igual';es_CO = 'Menor o igual';tr = 'Daha az veya eşit';it = 'Meno o uguale';de = 'Weniger oder gleich'"));
		ElsIf KindInString = "InList" Then
			Rule.AvailableComparisonTypes.Add(DataCompositionComparisonType.InList,		 	NStr("en = 'In the list'; ru = 'В списке';pl = 'Na liście';es_ES = 'En la lista';es_CO = 'En la lista';tr = 'Listede';it = 'Nell''elenco';de = 'In der Liste'"));
		ElsIf KindInString = "NotInList" Then
			Rule.AvailableComparisonTypes.Add(DataCompositionComparisonType.NotInList,		NStr("en = 'Not in the list'; ru = 'Не в списке';pl = 'Nie na liście';es_ES = 'No en la lista';es_CO = 'No en la lista';tr = 'Listede değil';it = 'Non in elenco';de = 'Nicht in der Liste'"));
		ElsIf KindInString = "InHierarchy" Then
			Rule.AvailableComparisonTypes.Add(DataCompositionComparisonType.InHierarchy,	NStr("en = 'In group'; ru = 'В группе';pl = 'W grupie';es_ES = 'En grupo';es_CO = 'En grupo';tr = 'Grupta';it = 'In gruppo';de = 'In der Gruppe'"));
		ElsIf KindInString = "NotInHierarchy" Then
			Rule.AvailableComparisonTypes.Add(DataCompositionComparisonType.NotInHierarchy,	NStr("en = 'Not in group'; ru = 'Не в группе';pl = 'Nie w grupie';es_ES = 'No en grupo';es_CO = 'No en grupo';tr = 'Grupta değil';it = 'Non nel gruppo';de = 'Nicht in der Gruppe'"));
		ElsIf KindInString = "Filled" Then
			Rule.AvailableComparisonTypes.Add(DataCompositionComparisonType.Filled,			NStr("en = 'Filled'; ru = 'Заполнено';pl = 'Wypełniono';es_ES = 'Rellenado';es_CO = 'Rellenado';tr = 'Dolduruldu';it = 'Compilato';de = 'Ausgefüllt'"));
		ElsIf KindInString = "NotFilled" Then
			Rule.AvailableComparisonTypes.Add(DataCompositionComparisonType.NotFilled,	 	NStr("en = 'Not filled'; ru = 'Не заполнено';pl = 'Nie wypełniono';es_ES = 'No rellenado';es_CO = 'No rellenado';tr = 'Doldurulmadı';it = 'Non compilato';de = 'Nicht ausgefüllt'"));
		ElsIf KindInString = "BeginsWith" Then
			Rule.AvailableComparisonTypes.Add(DataCompositionComparisonType.BeginsWith,	 	NStr("en = 'Begins with'; ru = 'Начинается с';pl = 'Zaczyna się od';es_ES = 'Empieza con';es_CO = 'Empieza con';tr = 'İle başlar';it = 'Comincia con';de = 'Beginnt mit'"));
		ElsIf KindInString = "NotBeginsWith" Then
			Rule.AvailableComparisonTypes.Add(DataCompositionComparisonType.NotBeginsWith,	NStr("en = 'Does not begin with'; ru = 'Не начинается с';pl = 'Nie zaczyna się od';es_ES = 'No empieza con';es_CO = 'No empieza con';tr = 'İle başlamaz';it = 'Non comincia con';de = 'Beginnt nicht mit'"));
		ElsIf KindInString = "Contains" Then
			Rule.AvailableComparisonTypes.Add(DataCompositionComparisonType.Contains,		NStr("en = 'Contains'; ru = 'Содержит';pl = 'Zawiera';es_ES = 'Contiene';es_CO = 'Contiene';tr = 'İçerir';it = 'Contiene';de = 'Enthält'"));
		ElsIf KindInString = "NotContains" Then
			Rule.AvailableComparisonTypes.Add(DataCompositionComparisonType.NotContains,	NStr("en = 'Does not contain'; ru = 'Не содержит';pl = 'Nie zawiera';es_ES = 'No contiene';es_CO = 'No contiene';tr = 'İçermez';it = 'Non contiene';de = 'Enthält nicht'"));
		EndIf;
	EndDo;
	
	Rule.ComparisonType = Rule.AvailableComparisonTypes[DefaultTypeNumber-1].Value;
	
EndProcedure

// Function generates the template for the Details logical query operator
//
// Parameters:
//  ComparisonTypeRules	 - DataCompositionComparisonType	 - makes sense for
//  the TemplateRow row values		 - String	 - the
// Return value source value:
//  String - template for using in the query
Function OperatorTemplateDetails(ComparisonTypeRules, val RowTemplate) Export
	
	// Substitute service characters from the source row
	CharsToReplace = "%_[]";
	For CharacterNumber = 1 To StrLen(RowTemplate) Do
		Char = Mid(CharsToReplace, CharacterNumber, 1);
		RowTemplate = StrReplace(RowTemplate, Mid(CharsToReplace, CharacterNumber, 1), "§" + Char);
	EndDo;
	
	If ComparisonTypeRules = DataCompositionComparisonType.BeginsWith Then
		RowTemplate = RowTemplate + "%";
	ElsIf ComparisonTypeRules = DataCompositionComparisonType.NotBeginsWith Then
		RowTemplate = RowTemplate + "%";
	ElsIf ComparisonTypeRules = DataCompositionComparisonType.Contains Then
		RowTemplate = "%" + RowTemplate + "%";
	ElsIf ComparisonTypeRules = DataCompositionComparisonType.NotContains Then
		RowTemplate = "%" + RowTemplate + "%";
	EndIf;
	
	Return RowTemplate;
	
EndFunction

// Function generates a condition for placing to query filter
//
// Parameters:
//  Field				 - String	 - query field on which
//  the RuleComparisonType condition is imposed	 - DataCompositionComparisonType	 - the
//  ParameterName comparison kind		 - String	 - name of
// the Return value set parameter:
//  String - query selection condition
Function ComparisonCondition(Field, ComparisonTypeRules, ParameterName) Export
	
	If ComparisonTypeRules = DataCompositionComparisonType.Equal Then
		ComparisonCondition = Field + " = " + "&" + ParameterName;
	ElsIf ComparisonTypeRules = DataCompositionComparisonType.NotEqual Then
		ComparisonCondition = Field + " <> " + "&" + ParameterName;
	ElsIf ComparisonTypeRules = DataCompositionComparisonType.Greater Then
		ComparisonCondition = Field + " > " + "&" + ParameterName;
	ElsIf ComparisonTypeRules = DataCompositionComparisonType.GreaterOrEqual Then
		ComparisonCondition = Field + " >= " + "&" + ParameterName;
	ElsIf ComparisonTypeRules = DataCompositionComparisonType.Less Then
		ComparisonCondition = Field + " < " + "&" + ParameterName;
	ElsIf ComparisonTypeRules = DataCompositionComparisonType.LessOrEqual Then
		ComparisonCondition = Field + " <= " + "&" + ParameterName;
	ElsIf ComparisonTypeRules = DataCompositionComparisonType.InList Then
		ComparisonCondition = Field + " IN " + "(&" + ParameterName + ")";
	ElsIf ComparisonTypeRules = DataCompositionComparisonType.NotInList Then
		ComparisonCondition = "Not " + Field + " IN " + "(&" + ParameterName + ")";
	ElsIf ComparisonTypeRules = DataCompositionComparisonType.InHierarchy Then
		ComparisonCondition = Field + " IN HIERARCHY " + "(&" + ParameterName + ")";
	ElsIf ComparisonTypeRules = DataCompositionComparisonType.NotInHierarchy Then
		ComparisonCondition = "Not " + Field + " IN HIERARCHY " + "(&" + ParameterName + ")";
	ElsIf ComparisonTypeRules = DataCompositionComparisonType.Filled Then
		ComparisonCondition = Field + " <> " + "&" + ParameterName;
	ElsIf ComparisonTypeRules = DataCompositionComparisonType.NotFilled Then
		ComparisonCondition = Field + " = " + "&" + ParameterName;
	ElsIf ComparisonTypeRules = DataCompositionComparisonType.BeginsWith Then
		ComparisonCondition = Field + " LIKE " + "&" + ParameterName + " ESCAPE ""§""";
	ElsIf ComparisonTypeRules = DataCompositionComparisonType.NotBeginsWith Then
		ComparisonCondition = "Not " + Field + " LIKE " + "&" + ParameterName + " ESCAPE ""§""";
	ElsIf ComparisonTypeRules = DataCompositionComparisonType.Contains Then
		ComparisonCondition = Field + " LIKE " + "&" + ParameterName + " ESCAPE ""§""";
	ElsIf ComparisonTypeRules = DataCompositionComparisonType.NotContains Then
		ComparisonCondition = "Not " + Field + " LIKE " + "&" + ParameterName + " ESCAPE ""§""";
	EndIf;
	
	Return ComparisonCondition;
	
EndFunction

// Returns the last item of structure - grouping
Function GetLastStructureItem(SettingsStructureItem, Rows = True) Export
	
	If TypeOf(SettingsStructureItem) = Type("DataCompositionSettingsComposer") Then
		Settings = SettingsStructureItem.Settings;
	ElsIf TypeOf(SettingsStructureItem) = Type("DataCompositionSettings") Then
		Settings = SettingsStructureItem;
	Else
		Return Undefined;
	EndIf;
	
	Structure = Settings.Structure;
	If Structure.Count() = 0 Then
		Return Settings;
	EndIf;
	
	If Rows Then
		NameStructureTable = "Rows";
		NameStructureChart = "Series";
	Else
		NameStructureTable = "Columns";
		NameStructureChart = "Points";
	EndIf;
	
	While True Do
		StructureItem = Structure[0];
		If TypeOf(StructureItem) = Type("DataCompositionTable") AND StructureItem[NameStructureTable].Count() > 0 Then
			If StructureItem[NameStructureTable][0].Structure.Count() = 0 Then
				Structure = StructureItem[NameStructureTable];
				Break;
			EndIf;
			Structure = StructureItem[NameStructureTable][0].Structure;
		ElsIf TypeOf(StructureItem) = Type("DataCompositionChart") AND StructureItem[NameStructureChart].Count() > 0 Then
			If StructureItem[NameStructureChart][0].Structure.Count() = 0 Then
				Structure = StructureItem[NameStructureChart];
				Break;
			EndIf;
			Structure = StructureItem[NameStructureChart][0].Structure;
		ElsIf TypeOf(StructureItem) = Type("DataCompositionGroup")
			  OR TypeOf(StructureItem) = Type("DataCompositionTableGroup")
			  OR TypeOf(StructureItem) = Type("DataCompositionChartGroup") Then
			If StructureItem.Structure.Count() = 0 Then
				Break;
			EndIf;
			Structure = StructureItem.Structure;
		ElsIf TypeOf(StructureItem) = Type("DataCompositionTable") Then
			Return StructureItem[NameStructureTable];
		ElsIf TypeOf(StructureItem) = Type("DataCompositionChart")	Then
			Return StructureItem[NameStructureChart];
		Else
			Return StructureItem;
		EndIf;
	EndDo;
	
	Return Structure[0];
	
EndFunction

Procedure ExecuteProductSegmentsGeneration(Parameters = Undefined, ResultAddress = Undefined) Export

	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.ProductSegmentGeneration);
	
	If IsBlankString(UserName()) Then
		SetPrivilegedMode(True);
	EndIf;
	
	EventName = NStr("en = 'Product segment generation. Scheduled launch'; ru = 'Генерирование сегмента номенклатуры. Запуск по расписанию';pl = 'Generacja segmentu produktu. Zaplanowane uruchomienie';es_ES = 'Generación del segmento del producto. Lanzamiento programado';es_CO = 'Generación del segmento del producto. Lanzamiento programado';tr = 'Ürün segmenti oluşturma. Planlanmış başlatma.';it = 'Generazione segmento articolo. Avvio pianificato';de = 'Generierung von Produktsegmenten. Geplanter Start'", CommonClientServer.DefaultLanguageCode());
	WriteLogEvent(
		EventName,
		EventLogLevel.Note,
		,
		,
		NStr("en = 'Start'; ru = 'Начало';pl = 'Rozpoczęcie';es_ES = 'Iniciar';es_CO = 'Iniciar';tr = 'Başlangıç';it = 'Inizio';de = 'Starten'",
		CommonClientServer.DefaultLanguageCode()));
	Try
		If TypeOf(Parameters) = Type("Structure")
			And Parameters.Property("Segment") Then
			GenerateProductSegments(Parameters.Segment);
		Else
			GenerateProductSegments();
		EndIf;
	Except
		
		WriteLogEvent(
			EventName, 
			EventLogLevel.Error,
			"",
			NStr("en = 'Product segment generation error'; ru = 'Ошибка генерирования сегмента номенклатуры';pl = 'Błąd generacji segmentu produktu';es_ES = 'Error de generación de segmento del producto';es_CO = 'Error de generación de segmento del producto';tr = 'Ürün segmenti oluşturma hatası';it = 'Errore di generazione segmento articolo';de = 'Fehler bei der Generierung von Produktsegmenten'", CommonClientServer.DefaultLanguageCode()),
			DetailErrorDescription(ErrorInfo()));
		Raise DetailErrorDescription(ErrorInfo());
	EndTry;
	
	WriteLogEvent(EventName, EventLogLevel.Note, "", NStr("en = 'Finish'; ru = 'Готово';pl = 'Gotowe';es_ES = 'Finalizar';es_CO = 'Finalizar';tr = 'Bitiş';it = 'Termina';de = 'Abschluss'", CommonClientServer.DefaultLanguageCode()));
	
EndProcedure

Procedure GenerateProductSegments(SegmentRef = Undefined) Export

	PM = PrivilegedMode();
	If Not PM Then
		SetPrivilegedMode(True);
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ProductSegments.Ref AS Segment
	|FROM
	|	Catalog.ProductSegments AS ProductSegments
	|WHERE
	|	&SegmentCondition
	|	AND NOT ProductSegments.DeletionMark";
	
	If ValueIsFilled(SegmentRef) Then
		Query.Text = StrReplace(Query.Text, "&SegmentCondition", "ProductSegments.Ref = &Segment");
		Query.SetParameter("Segment", SegmentRef);
	Else
		Query.Text = StrReplace(Query.Text, "&SegmentCondition", "TRUE");	
	EndIf;
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		
		ProductsTable = Catalogs.ProductSegments.GetSegmentContent(Selection.Segment);
		
		RecordSet = InformationRegisters.ProductSegments.CreateRecordSet();
		RecordSet.Filter.Segment.Set(Selection.Segment);
		
		For Each TableRow In ProductsTable Do
			Record = RecordSet.Add();
			Record.Segment = Selection.Segment;
			Record.Product = TableRow.Product;
			Record.Characteristic = TableRow.Variant;
		EndDo;
		
		RecordSet.Write();
		
	EndDo;
	
	If Not PM Then
		SetPrivilegedMode(False);
	EndIf;
	
EndProcedure

#EndRegion