#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure FillNewGLAccounts(DocumentName, Fields) Export
	
	ArrayOfRefs = DocumentsForFillingGLAccounts(DocumentName, Fields);
	For Each Ref In ArrayOfRefs Do
		FillGLAccountInTable(Ref, DocumentName, Fields);
	EndDo;
	
	RefsCount = ArrayOfRefs.Count();
	If RefsCount > 0 Then
		
		EventName = EventName(DocumentName);
		
		If RefsCount = 1 Then
			Comment = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 document was overwritten'; ru = '%1 документ был перезаписан.';pl = '%1 dokument został nadpisany';es_ES = 'El documento %1 ha sido sobrescrito';es_CO = 'El documento %1 ha sido sobrescrito';tr = '%1 belgenin üzerine yazılmıştır';it = 'il documento %1 è stato sovrascritto';de = '%1 Dokument wurde überschrieben'", CommonClientServer.DefaultLanguageCode()),
				RefsCount);
		Else
			Comment = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 documents were overwritten'; ru = '%1 документов было перезаписано.';pl = '%1 dokument został nadpisany';es_ES = 'Los documentos %1 han sido sobrescritos';es_CO = 'Los documentos %1 han sido sobrescritos';tr = '%1 belgelerin üzerine yazılmıştır';it = 'i documenti %1 sono stati sovrascritti';de = '%1 Dokumente wurden überschrieben'", CommonClientServer.DefaultLanguageCode()),
			RefsCount);
		EndIf;
		
		WriteLogEvent(EventName, EventLogLevel.Information,,, Comment);
		
	EndIf;
	
EndProcedure

Function GLAccountFields() Export
	Return New Structure("Source, Receiver, Parameter", "", "", "");
EndFunction

// Function returns the list of the "key" attributes names.
//
Function GetObjectAttributesBeingLocked() Export
	
	Result = New Array;
	
	Return Result;
	
EndFunction

Function AccountingRegisterName(TypeOfEntries = Undefined) Export

	Return "AccountingJournalEntries";

EndFunction

#EndRegion

#EndIf

#Region EventHandlers

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	If Not Parameters.Filter.Property("TypeOfAccount")
		And (Not Parameters.Property("AllowHeaderAccountsSelection")
			Or Not Parameters.AllowHeaderAccountsSelection) Then
		
		AccountTypes = New Array;
		HeaderItem = Enums.GLAccountsTypes.Header;
		
		For Each Item In Enums.GLAccountsTypes Do
			If Not Item = HeaderItem Then
				AccountTypes.Add(Item);
			EndIf;
		EndDo;
		
		Parameters.Filter.Insert("TypeOfAccount", AccountTypes);
		
	EndIf;
	
	NativeLanguagesSupportServer.ChoiceDataGetProcessing(
		ChoiceData,
		Parameters,
		StandardProcessing,
		Metadata.ChartsOfAccounts.PrimaryChartOfAccounts);
	
EndProcedure

#EndIf

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	StandardProcessing = False;
	Fields.Add("Code");
	Fields.Add("Description");
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
	StandardProcessing = False;
	Presentation = Data.Code + " " + ?(IsBlankString(Presentation), Data.Description, Presentation);

EndProcedure

#EndRegion

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

Procedure AddUnionInQueryText(QueryText)
	
	If ValueIsFilled(QueryText) Then
		QueryText = QueryText + "
			|UNION ALL
			|";
	EndIf;
	
EndProcedure

Function EventName(DocumentName)
	
	EventName = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Fill GL Accounts in document.%1'; ru = 'Необходимо заполнить счета учета в документах.%1';pl = 'Wypełnij księgę główną konta w dokumencie rozliczeń rozrachunków.%1';es_ES = 'Rellenar las cuentas del libro mayor en el documento.%1';es_CO = 'Rellenar las cuentas del libro mayor en el documento.%1';tr = 'Belgedeki Muhasebe hesaplarını doldurun. %1';it = 'Compilare i conti mastro nel documento. %1';de = 'Die Hauptbuch-Konten im Beleg ausfüllen.%1'", CommonClientServer.DefaultLanguageCode()),
		DocumentName);
		
	Return EventName;
	
EndFunction

Function DocumentsForFillingGLAccounts(DocumentName, Tables)
	
	Refs = New Array();
	
	Tempalate = "
	|SELECT DISTINCT
	|	Table.Ref AS Ref
	|FROM
	|	&DocumentTable AS Table
	|WHERE
	|	&Condition
	|";
	
	Query = New Query();
	
	DocumentQuery = "";
	For Each Table In Tables Do
		
		AddUnionInQueryText(DocumentQuery);
		
		If ValueIsFilled(Table.Name) Then
			DocumentTable = StringFunctionsClientServer.SubstituteParametersToString(
				"Document.%1.%2",
				DocumentName,
				Table.Name);
		Else
			DocumentTable = StringFunctionsClientServer.SubstituteParametersToString(
				"Document.%1",
				DocumentName);
		EndIf;
			
		TableTemplate = StrReplace(Tempalate, "&DocumentTable", DocumentTable);
			
		TableQueryText = "";
		For Each Condition In Table.Conditions Do
			
			AddUnionInQueryText(TableQueryText);
			
			If Left(Condition.Source, 1) = "&" Then
				SourceField = "";
				ParameterName = StrReplace(Condition.Source, "&", "");
				Query.SetParameter(ParameterName, Condition.Parameter);
			Else
				SourceField = "Table.";
			EndIf;
			
			ConditionText = StringFunctionsClientServer.SubstituteParametersToString(
				"%1%2 <> VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
				|	AND Table.%3 = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)",
				SourceField,
				Condition.Source,
				Condition.Receiver);
				
			ConditionQueryText = StrReplace(TableTemplate, "&Condition", ConditionText);
			TableQueryText = TableQueryText + ConditionQueryText;
			
		EndDo;
		
		DocumentQuery = DocumentQuery + TableQueryText;
		
	EndDo;
		
	QueryTemplate = "
	|SELECT DISTINCT
	|	Table.Ref AS Ref
	|FROM
	|	&DocumentQuery AS Table
	|";
	
	Query.Text = StrReplace(QueryTemplate, "&DocumentQuery", "(" + DocumentQuery + ")");
	
	Result = Query.Execute().Unload();
	
	Refs = Result.UnloadColumn("Ref");
	
	Return Refs;
	
EndFunction

Procedure FillGLAccountInTable(Ref, DocumentName, Tables)
	
	Template = "
	|SELECT
	|	&LineNumber AS LineNumber,
	|	""&TableName"" AS TableName,
	|	&CasesOfNewGLAccounts
	|FROM
	|	&SourceTable AS Table
	|WHERE
	|	Table.Ref = &Ref";
	
	TemplateOfNewGLAccount = "
	|
	|	CASE
	|		WHEN Table.%1 = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|			AND %2%3 <> VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		THEN %2%3
	|		ELSE Table.%1
	|	END AS %1";
	
	Query = New Query();
	Query.SetParameter("Ref", Ref);
	
	Object = Ref.GetObject();
	
	GLAccountWasChanged = False;
	For Each Table In Tables Do
		
		CasesOfNewGLAccounts = "";
		For Each Condition In Table.Conditions Do
			
			If ValueIsFilled(CasesOfNewGLAccounts) Then
				CasesOfNewGLAccounts = CasesOfNewGLAccounts + ",";
			EndIf;
			
			If Left(Condition.Source, 1) = "&" Then
				SourceField = "";
				ParameterName = StrReplace(Condition.Source, "&", "");
				Query.SetParameter(ParameterName, Condition.Parameter);
			Else
				SourceField = "Table.";
			EndIf;
			
			NewGLAccount = StringFunctionsClientServer.SubstituteParametersToString(
				TemplateOfNewGLAccount,
				Condition.Receiver,
				SourceField,
				Condition.Source);
			
			CasesOfNewGLAccounts = CasesOfNewGLAccounts + NewGLAccount;
			
		EndDo;
		
		If ValueIsFilled(Table.Name) Then
			
			SourceTable = StringFunctionsClientServer.SubstituteParametersToString(
				"Document.%1.%2",
				DocumentName,
				Table.Name);
				
			LineNumber = "Table.LineNumber";
			
		Else
			
			SourceTable = StringFunctionsClientServer.SubstituteParametersToString(
				"Document.%1",
				DocumentName);
				
			LineNumber = "1";
			
		EndIf;
			
		TableTemplate = StrReplace(Template, "&TableName", Table.Name);
		TableTemplate = StrReplace(TableTemplate, "&LineNumber", LineNumber);
		TableTemplate = StrReplace(TableTemplate, "&SourceTable", SourceTable);
		TableTemplate = StrReplace(TableTemplate, "&CasesOfNewGLAccounts", CasesOfNewGLAccounts);
		
		Query.Text = TableTemplate;
		
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			GLAccountWasChanged = True;
			If ValueIsFilled(Selection.TableName) Then
				CurrentRow = Object[Selection.TableName][Selection.LineNumber - 1];
				FillPropertyValues(CurrentRow, Selection, ,"LineNumber");
			Else
				FillPropertyValues(Object, Selection);
			EndIf;
		EndDo;
	EndDo;
	
	If Not GLAccountWasChanged Then
		Return;
	EndIf;
	
	BeginTransaction();
	Try
		Object.Write();
		CommitTransaction();
	Except
		RollbackTransaction();
		
		EventName = EventName(DocumentName);
		Comment = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot rewrite document ""%1""'; ru = 'Не удалось перезаписать документ ""%1""';pl = 'Nie można przepisać dokumentu ""%1""';es_ES = 'Ha ocurrido un error al sobrescribir el documento ""%1""';es_CO = 'Ha ocurrido un error al sobrescribir el documento ""%1""';tr = '""%1"" belgesi yeniden yazılamıyor';it = 'Impossibile riscrivere il documento ""%1""';de = 'Das Dokument ""%1"" kann nicht neu gespeichert werden'", CommonClientServer.DefaultLanguageCode()),
			Ref);
			
		WriteLogEvent(EventName, EventLogLevel.Error,,, Comment);
		
	EndTry;
	
EndProcedure

#EndRegion

#EndIf
