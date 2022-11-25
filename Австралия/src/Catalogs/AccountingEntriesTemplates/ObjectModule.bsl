#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnCopy(CopiedObject)
	
	If CopiedObject.Status = Enums.AccountingEntriesTemplatesStatuses.Draft Then
		PlanStartDate	= CopiedObject.PlanStartDate;
		PlanEndDate		= CopiedObject.PlanEndDate;
	Else
		PlanStartDate	= CopiedObject.StartDate;
		PlanEndDate		= CopiedObject.EndDate;
		
		StartDate	= Date(1, 1, 1);
		EndDate		= Date(1, 1, 1);
	EndIf;
	
	Status = Enums.AccountingEntriesTemplatesStatuses.Draft;
	Author = Users.CurrentUser();
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If TypeOf(FillingData) = Type("Structure") And Not IsFolder Then
		
		FillPropertyValues(ThisObject, FillingData);
		
	EndIf;
	
	FillByDefault();
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	TabsToCustomCheck = New Array;
	TabsToCustomCheck.Add("Entries");
	TabsToCustomCheck.Add("EntriesSimple");

	AttributesToCustomCheck = ExtractAttributesToCustomCheck(CheckedAttributes, TabsToCustomCheck);
	DeleteAttributesToCustomCheck(CheckedAttributes, AttributesToCustomCheck);
		
	If Status = Enums.AccountingEntriesTemplatesStatuses.Draft Then
		
		CheckedAttributes.Clear();
		AttributesToCustomCheck.Clear();
		
	ElsIf Status = Enums.AccountingEntriesTemplatesStatuses.Active Then
		
		If DeletionMark Then 
			ErrorMessage = NStr("en = 'Cannot save the changes. This template is marked for deletion.'; ru = 'Не удалось сохранить изменения. Шаблон помечен на удаление.';pl = 'Nie można zapisać zmian. Ten szablon jest zaznaczony do usunięcia.';es_ES = 'No se pueden guardar los cambios. Esta plantilla está marcada para ser eliminada.';es_CO = 'No se pueden guardar los cambios. Esta plantilla está marcada para ser eliminada.';tr = 'Değişiklikler kaydedilemiyor. Bu şablon silinmek üzere işaretlenmiş.';it = 'Impossibile salvare le modifiche. Il modello è contrassegnato per l''eliminazione.';de = 'Fehler beim Speichern von Änderungen. Diese Vorlage ist zum Löschen markiert.'");
			DriveServer.ShowMessageAboutError(ThisObject, ErrorMessage, , , , Cancel);
		EndIf;
		
		If Entries.Count() = 0 And EntriesSimple.Count() = 0 Then 
			ErrorMessage = NStr("en = 'Cannot save the changes. The Entries tab must contain at least one entry.'; ru = 'Не удалось сохранить изменения. Вкладка ""Проводки"" должна содержать хотя бы одну проводку.';pl = 'Nie można zapisać zmian. Karta Wpisy powinna zawierać co najmniej jeden wpis.';es_ES = 'No se pueden guardar los cambios. La pestaña Entradas de diario debe contener al menos una entrada de diario.';es_CO = 'No se pueden guardar los cambios. La pestaña Entradas de diario debe contener al menos una entrada de diario.';tr = 'Değişiklikler kaydedilemiyor. Girişler sekmesi en az bir giriş içermelidir.';it = 'Impossibile salvare le modifiche. La scheda Voci deve contenere almeno una voce.';de = 'Fehler beim Speichern von Änderungen. Die Registerkarte von Buchungen muss zumindest eine Buchung enthalten.'");
			DriveServer.ShowMessageAboutError(ThisObject, ErrorMessage, , , , Cancel);
		EndIf;
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PlanStartDate");
		
		If ValueIsFilled(EndDate) And EndDate < StartDate Then
			ErrorMessage = NStr("en = '""To"" date must be equal to or later than ""From"" date. Edit ""to"" date, then try again.'; ru = 'Дата в поле ""По"" не может быть меньше даты в поле ""С"". Отредактируйте дату в поле ""По"" и повторите попытку.';pl = 'Data ""Do"" powinna być równa lub późniejsza niż data ""Od"". Edytuj datę ""do"", następnie spróbuj ponownie.';es_ES = 'La fecha ""Hasta"" debe ser igual o posterior a la fecha ""Desde"". Edite la fecha ""Hasta"" y vuelva a intentarlo.';es_CO = 'La fecha ""Hasta"" debe ser igual o posterior a la fecha ""Desde"". Edite la fecha ""Hasta"" y vuelva a intentarlo.';tr = '""Bitiş"" tarihi ""Başlangıç"" tarihi ile aynı veya daha sonra olmalıdır. ""Bitiş"" tarihini değiştirip tekrar deneyin.';it = 'La data ""fino a"" deve essere uguale o successiva alla data ""Da"". Modificare la data ""fino a"", poi riprovare.';de = '""Bis zu"" muss gleich oder später als Datum ""Von "" liegen. Bearbeiten Sie das Datum ""Bis zum"", dann versuchen Sie erneut.'");
			DriveServer.ShowMessageAboutError(ThisObject, ErrorMessage, , , "EndDate", Cancel);
		EndIf;
		
		CheckParametersFilling(Cancel);
		CheckDrCrFilling(Cancel);
		
		AccountValidation(Cancel);
		
		If Common.ObjectAttributeValue(ChartOfAccounts, "TypeOfEntries") = Enums.ChartsOfAccountsTypesOfEntries.Compound Then
			CheckAnalyticals(Cancel);
			CheckAnalyticalDimensionsSet(Cancel);
		Else
			CheckAnalyticalsSimple(Cancel);
			CheckAnalyticalDimensionsSetEntriesSimple(Cancel);
		EndIf;
		
		CheckCustomAttributeFilling(Cancel, AttributesToCustomCheck);
		
	EndIf;
	
	If Not ValueIsFilled(Company) And DriveServer.IsRestrictedByCompany() Then
		
		CheckedAttributes.Add("Company");
		
	EndIf;
	
EndProcedure

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If IsNew() Then
		ElemRef = Catalogs.AccountingEntriesTemplates.GetRef();
		SetNewObjectRef(ElemRef);
	Else
		ElemRef = Ref;
		
		If Status = Enums.AccountingEntriesTemplatesStatuses.Draft 
			And Status <> Common.ObjectAttributeValue(Ref, "Status") Then
			
			PlanStartDate = Common.ObjectAttributeValue(Ref, "StartDate");
			
		EndIf;
		
	EndIf;
	
	CheckStatusBeforeDeletionMark(Cancel);
	
	If Not Cancel
		And (Not AdditionalProperties.Property("SubordinateTemplatesChecked")
			Or Not AdditionalProperties.SubordinateTemplatesChecked) Then
		
		CheckSubordinateTemplates(Cancel);
		
	EndIf;
	
	If Not Cancel Then
		
		ClearSubordinateTemplates();
		InformationRegisters.AccountingEntriesTemplatesStatuses.SaveStatusHistory(ElemRef, Status, StartDate, EndDate);
	EndIf;
	
EndProcedure

Procedure OnReadPresentationsAtServer(Object) Export
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

#EndRegion

#Region Private

Procedure FillByDefault()
	
	If Not ValueIsFilled(Company) Then
		Company = Catalogs.Companies.CompanyByDefault();
	EndIf;
	
	Status = Enums.AccountingEntriesTemplatesStatuses.Draft;
	Author = Users.CurrentUser();
	
	If ValueIsFilled(ChartOfAccounts) And ValueIsFilled(DocumentType) And ValueIsFilled(TypeOfAccounting) Then
		Description = StrTemplate(NStr("en = '%1: %2 (%3)'; ru = '%1: %2 (%3)';pl = '%1: %2 (%3)';es_ES = '%1: %2 (%3)';es_CO = '%1: %2 (%3)';tr = '%1: %2 (%3)';it = '%1: %2 (%3)';de = '%1: %2 (%3)'"), DocumentTypeSynonym, TypeOfAccounting, ChartOfAccounts);
	EndIf;
	
EndProcedure

#Region CustomFillingCheck

Function ExtractAttributesToCustomCheck(CheckedAttributes, TabsToCheck)
	
	AttributesToCustomCheck = New Array;
	
	For Each CheckedAttribute In CheckedAttributes Do
		
		AttrArray = StrSplit(CheckedAttribute, ".", False);
		If AttrArray.Count() < 2 Then
			Continue;
		EndIf;
		
		If TabsToCheck.Find(AttrArray[0]) <> Undefined Then
			AttributesToCustomCheck.Add(CheckedAttribute);
		EndIf;
			
	EndDo;
		
	Return AttributesToCustomCheck;
	
EndFunction

Function GetSynonym(TabularSectionMetadata, AttributeName)
	
	Return TabularSectionMetadata.Attributes[AttributeName].Synonym;
	
EndFunction

Procedure CheckCustomAttributeFilling(Cancel, CheckedAttributes)
	
	AttributesStructure = New Structure;
	TabSectionsToCheck = New Array;
	
	For Each CheckedAttribute In CheckedAttributes Do
		
		AttrArray = StrSplit(CheckedAttribute, ".", False);
		CurrentTab		 = AttrArray[0];
		CurrentAttribute = AttrArray[1];
		
		If Not AttributesStructure.Property(CurrentTab) Then
			AttributesStructure.Insert(CurrentTab, New Array);
		EndIf;
		
		AttributesStructure[CurrentTab].Add(CurrentAttribute);
	EndDo;
	
	ObjectMetadata = Metadata();
	
	StandardNameAttributes = "Content, DrCr, Mode"; // For this attributes there are no synonyms,
													// so they would have standard names in the form.
	
	For Each CheckedTab In AttributesStructure Do
		
		TSMetadata = ObjectMetadata.TabularSections[CheckedTab.Key];
		TSSynonym  = TSMetadata.Synonym;
		CompoundEntries = (TSMetadata.Attributes.Find("EntryLineNumber") <> Undefined);
		
		For Each TSRow In ThisObject[CheckedTab.Key] Do
			
			For Each AttributeName In CheckedTab.Value Do
				
				If ValueIsFilled(TSRow[AttributeName]) Then
					Continue;
				EndIf;
				
				If Left(AttributeName, 7) = "Account" Then
					
					FieldName = StrTemplate("DefaultAccountType%1", Mid(AttributeName, 8));
					
					If ValueIsFilled(TSRow[FieldName]) Then
						Continue;
					EndIf;
					
				EndIf;
				
				AttributeSynonym = GetSynonym(TSMetadata, AttributeName);
				AttributeName	 = AttributeName + ?(StrFind(StandardNameAttributes, AttributeName) <> 0, "", "Synonym"); 
				LineNumber		 = ?(CompoundEntries, StrTemplate("%1/%2", TSRow.EntryNumber, TSRow.EntryLineNumber), TSRow.LineNumber);
				
				ErrorTemplate	 = NStr("en = 'The ""%1"" is required on line %2 of the ""%3"" list'; ru = 'В строке %2 списка ""%3"" необходимо указать ""%1""';pl = '""%1"" jest wymagany w wierszu %2 listy ""%3""';es_ES = 'El ""%1"" se requiere en la línea %2 de la lista ""%3"".';es_CO = 'El ""%1"" se requiere en la línea %2 de la lista ""%3"".';tr = '""%3"" listesinin %2 satırında ""%1"" gerekli';it = '""%1"" è richiesto nella riga %2 dell''elenco ""%3""';de = '""%1"" ist in der Zeile %2 der ""%3"" Liste erforderlich.'");
				ErrorMessage	 = StrTemplate(ErrorTemplate, AttributeSynonym, LineNumber, TSSynonym);
				
				DriveServer.ShowMessageAboutError(ThisObject, ErrorMessage, CheckedTab.Key, TSRow.LineNumber, AttributeName, Cancel);
				
			EndDo;
			
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure DeleteAttributesToCustomCheck(CheckedAttributes, AttributesToCustomCheck)

	For Each CustomCheckAttr In AttributesToCustomCheck Do
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, CustomCheckAttr);
	EndDo;

EndProcedure

Procedure CheckParametersFilling(Cancel)
		
	Query = New Query;
	Query.Text = 
	"SELECT
	|	TemplatesParameters.ParameterName AS ParameterName,
	|	TemplatesParameters.LineNumber AS LineNumber,
	|	TemplatesParameters.LineNumber AS LinesCount
	|INTO ParametersTable
	|FROM
	|	&Parameters AS TemplatesParameters
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ParametersTable.ParameterName AS ParameterName,
	|	MAX(ParametersTable.LineNumber) AS LineNumber
	|FROM
	|	ParametersTable AS ParametersTable
	|
	|GROUP BY
	|	ParametersTable.ParameterName
	|
	|HAVING
	|	COUNT(DISTINCT ParametersTable.LinesCount) > 1";
	
	Query.SetParameter("Parameters", Parameters.Unload( , "ParameterName, LineNumber"));
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		ErrorTemplate = NStr("en = 'Cannot save the Accounting entries template. The Parameters tab contains duplicate items: %1.'; ru = 'Не удалось сохранить шаблон бухгалтерских проводок. Вкладка ""Параметры"" содержит дублирующиеся элементы: %1.';pl = 'Nie można zapisać szablonu Wpisy księgowe. Karta Parametry zawiera zduplikowane elementy: %1.';es_ES = 'No se puede guardar la plantilla de entradas contables. La pestaña Parámetros contiene elementos duplicados: %1.';es_CO = 'No se puede guardar la plantilla de entradas contables. La pestaña Parámetros contiene elementos duplicados: %1.';tr = 'Muhasebe girişleri şablonu kaydedilemiyor. Parametreler sekmesi tekrarlayan öğeler içeriyor: %1.';it = 'Impossibile salvare il modello di voci di contabilità. La scheda Parametri contiene elementi duplicati: %1.';de = 'Fehler beim Speichern der Vorlage von Buchungen. Die Registerkarte Parameter enthält verdoppelte Positionen: %1.'");
		ErrorMessage  = StrTemplate(ErrorTemplate, SelectionDetailRecords.ParameterName);
		
		DriveServer.ShowMessageAboutError(ThisObject, ErrorMessage, "Parameters", SelectionDetailRecords.LineNumber, "ParameterSynonym", Cancel);
		
	EndDo;

EndProcedure

Procedure CheckDrCrFilling(Cancel)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	AccountingEntriesTemplatesEntries.LineNumber AS LineNumber,
	|	AccountingEntriesTemplatesEntries.EntryNumber AS EntryNumber,
	|	AccountingEntriesTemplatesEntries.DrCr AS DrCr
	|INTO EntriesTable
	|FROM
	|	&Entries AS AccountingEntriesTemplatesEntries
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	EntriesTable.EntryNumber AS EntryNumber
	|INTO MissingEntries
	|FROM
	|	EntriesTable AS EntriesTable
	|
	|GROUP BY
	|	EntriesTable.EntryNumber
	|
	|HAVING
	|	COUNT(DISTINCT EntriesTable.DrCr) <> 2
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MissingEntries.EntryNumber AS EntryNumber,
	|	EntriesTable.DrCr AS DrCr
	|FROM
	|	MissingEntries AS MissingEntries
	|		INNER JOIN EntriesTable AS EntriesTable
	|		ON (EntriesTable.EntryNumber = MissingEntries.EntryNumber)
	|
	|GROUP BY
	|	MissingEntries.EntryNumber,
	|	EntriesTable.DrCr";
	
	Query.SetParameter("Entries", Entries.Unload( ,"LineNumber, EntryNumber, DrCr"));
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		MissingEntry = ?(SelectionDetailRecords.DrCr = Enums.DebitCredit.Dr, Enums.DebitCredit.Cr, Enums.DebitCredit.Dr);
		ErrorMessage = StrTemplate(
			NStr("en = 'Cannot save the changes. Entry #%1 must contain at least one %2 entry line.'; ru = 'Не удалось сохранить изменения. Проводка №%1 должна содержать хотя бы одну строку проводки %2.';pl = 'Nie można zapisać zmian. Wpis nr %1powinien zawierać co najmniej jeden wiersz wpisu %2.';es_ES = 'No se pueden guardar los cambios. La entrada #%1 debe contener al menos una %2 línea de entrada de diario.';es_CO = 'No se pueden guardar los cambios. La entrada #%1 debe contener al menos una %2 línea de entrada de diario.';tr = 'Değişiklikler kaydedilemiyor. %1 nolu giriş en az bir %2 giriş satırı içermelidir.';it = 'Impossibile salvare le modifiche. La voce #%1 deve contenere almeno una riga voce %2.';de = 'Fehler beim Speichern von Änderungen. Die Buchung Nr. %1 muss zumindest eine %2Buchungszeile enthalten.'"),
			SelectionDetailRecords.EntryNumber,
			MissingEntry);
		
		DriveServer.ShowMessageAboutError(ThisObject, ErrorMessage, , , , Cancel);
	EndDo;

EndProcedure

Procedure CheckAnalyticalDimensionsSet(Cancel)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	AccountingEntriesTemplatesEntries.LineNumber AS LineNumber,
	|	AccountingEntriesTemplatesEntries.Account AS Account,
	|	AccountingEntriesTemplatesEntries.AnalyticalDimensionsSet AS AnalyticalDimensionsSet
	|INTO EntriesTable
	|FROM
	|	&Entries AS AccountingEntriesTemplatesEntries
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	EntriesTable.LineNumber AS LineNumber,
	|	MasterChartOfAccounts.Description AS Account,
	|	EntriesTable.AnalyticalDimensionsSet AS AnalyticalDimensionsSet,
	|	MasterChartOfAccounts.AnalyticalDimensionsSet AS AnalyticalDimensionsSetAccount
	|FROM
	|	EntriesTable AS EntriesTable
	|		INNER JOIN ChartOfAccounts.MasterChartOfAccounts AS MasterChartOfAccounts
	|		ON EntriesTable.Account = MasterChartOfAccounts.Ref
	|WHERE
	|	VALUETYPE(EntriesTable.Account) = TYPE(ChartOfAccounts.MasterChartOfAccounts)
	|		AND MasterChartOfAccounts.AnalyticalDimensionsSet <> EntriesTable.AnalyticalDimensionsSet";
	
	Query.SetParameter("Entries", Entries.Unload( ,"LineNumber, Account, AnalyticalDimensionsSet"));
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		ErrorTemplate	= NStr("en = 'Cannot save the changes. Line %1 contains analytical dimensions set %2 that 
			|does not match analytical dimensions set of the account %3'; 
			|ru = 'Не удалось сохранить изменения. Строка %1 содержит набор аналитических измерений %2, который 
			|не соответствует набору аналитических измерений счета %3';
			|pl = 'Nie można zapisać zmian. Wiersz %1 zawiera zestaw wymiarów analitycznych %2, który 
			|nie jest zgodny z zestawem wymiarów analitycznych konta %3';
			|es_ES = 'No se pueden guardar los cambios. La línea %1 contiene un conjunto de dimensiones analíticas %2 que no coincide 
			| con el conjunto de dimensiones analíticas de la cuenta %3';
			|es_CO = 'No se pueden guardar los cambios. La línea %1 contiene un conjunto de dimensiones analíticas %2 que no coincide 
			| con el conjunto de dimensiones analíticas de la cuenta %3';
			|tr = 'Değişiklikler kaydedilemiyor. %1 satırı, %3 hesabının analitik boyut kümesiyle eşleşmeyen
			| %2 analitik boyut kümesini içeriyor';
			|it = 'Impossibile salvare le modifiche. La riga %1 contiene un set di dimensioni analitiche %2 che 
			|non corrisponde al set di dimensioni analitiche del conto %3';
			|de = 'Fehler beim Speichern von Änderungen. Die Zeile %1 enthält einen Satz analytischer Messungen %2der 
			| mit dem Satz analytischer Messungen des Kontos %3nicht übereinstimmt'");
		ErrorMessage	= StrTemplate(ErrorTemplate,
			SelectionDetailRecords.LineNumber,
			SelectionDetailRecords.AnalyticalDimensionsSet,
			SelectionDetailRecords.Account);
		DriveServer.ShowMessageAboutError(
			ThisObject,
			ErrorMessage,
			"Entries",
			SelectionDetailRecords.LineNumber,
			"AnalyticalDimensionsSet",
			Cancel);
		
	EndDo;
	
EndProcedure

Procedure CheckAnalyticalDimensionsSetEntriesSimple(Cancel)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	AccountingEntriesTemplatesEntries.LineNumber AS LineNumber,
	|	AccountingEntriesTemplatesEntries.AccountCr AS AccountCr,
	|	AccountingEntriesTemplatesEntries.AccountDr AS AccountDr,
	|	AccountingEntriesTemplatesEntries.AnalyticalDimensionsSetDr AS AnalyticalDimensionsSetDr,
	|	AccountingEntriesTemplatesEntries.AnalyticalDimensionsSetCr AS AnalyticalDimensionsSetCr
	|INTO EntriesTable
	|FROM
	|	&EntriesSimple AS AccountingEntriesTemplatesEntries
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	EntriesTable.LineNumber AS LineNumber,
	|	MasterChartOfAccountsCr.Description AS AccountCr,
	|	MasterChartOfAccountsDr.Description AS AccountDr,
	|	EntriesTable.AnalyticalDimensionsSetCr AS AnalyticalDimensionsSetCr,
	|	MasterChartOfAccountsCr.AnalyticalDimensionsSet AS AnalyticalDimensionsSetAccountCr,
	|	EntriesTable.AnalyticalDimensionsSetDr AS AnalyticalDimensionsSetDr,
	|	MasterChartOfAccountsCr.AnalyticalDimensionsSet AS AnalyticalDimensionsSetAccountDr,
	|	VALUETYPE(EntriesTable.AccountCr) = TYPE(ChartOfAccounts.MasterChartOfAccounts)
	|		AND MasterChartOfAccountsCr.AnalyticalDimensionsSet <> EntriesTable.AnalyticalDimensionsSetCr AS ErrorCr,
	|	VALUETYPE(EntriesTable.AccountDr) = TYPE(ChartOfAccounts.MasterChartOfAccounts)
	|		AND MasterChartOfAccountsDr.AnalyticalDimensionsSet <> EntriesTable.AnalyticalDimensionsSetDr AS ErrorDr
	|INTO MissingEntries
	|FROM
	|	EntriesTable AS EntriesTable
	|		LEFT JOIN ChartOfAccounts.MasterChartOfAccounts AS MasterChartOfAccountsCr
	|		ON EntriesTable.AccountCr = MasterChartOfAccountsCr.Ref
	|		LEFT JOIN ChartOfAccounts.MasterChartOfAccounts AS MasterChartOfAccountsDr
	|		ON EntriesTable.AccountDr = MasterChartOfAccountsDr.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MissingEntries.LineNumber AS LineNumber,
	|	MissingEntries.AccountCr AS AccountCr,
	|	MissingEntries.AccountDr AS AccountDr,
	|	MissingEntries.AnalyticalDimensionsSetCr AS AnalyticalDimensionsSetCr,
	|	MissingEntries.AnalyticalDimensionsSetAccountCr AS AnalyticalDimensionsSetAccountCr,
	|	MissingEntries.AnalyticalDimensionsSetDr AS AnalyticalDimensionsSetDr,
	|	MissingEntries.AnalyticalDimensionsSetAccountDr AS AnalyticalDimensionsSetAccountDr,
	|	MissingEntries.ErrorCr AS ErrorCr,
	|	MissingEntries.ErrorDr AS ErrorDr
	|FROM
	|	MissingEntries AS MissingEntries
	|WHERE
	|	(MissingEntries.ErrorCr
	|			OR MissingEntries.ErrorDr)";
	
	Query.SetParameter("EntriesSimple",
		EntriesSimple.Unload( ,"LineNumber, AccountCr, AccountDr, AnalyticalDimensionsSetCr, AnalyticalDimensionsSetDr"));
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		If SelectionDetailRecords.ErrorCr Then
			ErrorTemplate 	= NStr("en = 'Cannot save the changes. Line %1 contains analytical dimensions set %2 that 
				|does not match analytical dimensions set of the account %3'; 
				|ru = 'Не удалось сохранить изменения. Строка %1 содержит набор аналитических измерений %2, который 
				|не соответствует набору аналитических измерений счета %3';
				|pl = 'Nie można zapisać zmian. Wiersz %1 zawiera zestaw wymiarów analitycznych %2, który 
				|nie jest zgodny z zestawem wymiarów analitycznych konta %3';
				|es_ES = 'No se pueden guardar los cambios. La línea %1 contiene un conjunto de dimensiones analíticas %2que no coincide 
				| con el conjunto de dimensiones analíticas de la cuenta %3';
				|es_CO = 'No se pueden guardar los cambios. La línea %1 contiene un conjunto de dimensiones analíticas %2que no coincide 
				| con el conjunto de dimensiones analíticas de la cuenta %3';
				|tr = 'Değişiklikler kaydedilemiyor. %1 satırı, %3 hesabının analitik boyut kümesiyle eşleşmeyen
				| %2 analitik boyut kümesini içeriyor';
				|it = 'Impossibile salvare le modifiche. La riga %1 contiene un set di dimensioni analitiche %2 che 
				| non corrisponde al set di dimensioni analitiche del conto %3';
				|de = 'Fehler beim Speichern von Änderungen. Die Zeile %1 enthält einen Satz analytischer Messungen %2 der 
				| mit dem Satz analytischer Messungen des Kontos %3nicht übereinstimmt'");
			ErrorMessage 	= StrTemplate(ErrorTemplate,
				SelectionDetailRecords.LineNumber,
				SelectionDetailRecords.AnalyticalDimensionsSetCr,
				SelectionDetailRecords.AccountCr);
			DriveServer.ShowMessageAboutError(
				ThisObject,
				ErrorMessage,
				"EntriesSimple",
				SelectionDetailRecords.LineNumber,
				"AnalyticalDimensionsSetCr",
				Cancel);
		EndIf;
	
		If SelectionDetailRecords.ErrorDr Then
			ErrorTemplate 	= NStr("en = 'Cannot save the changes. Line %1 contains analytical dimensions set %2 that 
				|does not match analytical dimensions set of the account %3'; 
				|ru = 'Не удалось сохранить изменения. Строка %1 содержит набор аналитических измерений %2, который 
				|не соответствует набору аналитических измерений счета %3';
				|pl = 'Nie można zapisać zmian. Wiersz %1 zawiera zestaw wymiarów analitycznych %2, który 
				|nie jest zgodny z zestawem wymiarów analitycznych konta %3';
				|es_ES = 'No se pueden guardar los cambios. La línea %1 contiene un conjunto de dimensiones analíticas %2que no coincide 
				| con el conjunto de dimensiones analíticas de la cuenta %3';
				|es_CO = 'No se pueden guardar los cambios. La línea %1 contiene un conjunto de dimensiones analíticas %2que no coincide 
				| con el conjunto de dimensiones analíticas de la cuenta %3';
				|tr = 'Değişiklikler kaydedilemiyor. %1 satırı, %3 hesabının analitik boyut kümesiyle eşleşmeyen
				| %2 analitik boyut kümesini içeriyor';
				|it = 'Impossibile salvare le modifiche. La riga %1 contiene un set di dimensioni analitiche %2 che 
				| non corrisponde al set di dimensioni analitiche del conto %3';
				|de = 'Fehler beim Speichern von Änderungen. Die Zeile %1 enthält einen Satz analytischer Messungen %2 der 
				| mit dem Satz analytischer Messungen des Kontos %3nicht übereinstimmt'");
			ErrorMessage 	= StrTemplate(ErrorTemplate,
				SelectionDetailRecords.LineNumber,
				SelectionDetailRecords.AnalyticalDimensionsSetDr,
				SelectionDetailRecords.AccountDr);
			DriveServer.ShowMessageAboutError(
				ThisObject,
				ErrorMessage,
				"EntriesSimple",
				SelectionDetailRecords.LineNumber,
				"AnalyticalDimensionsSetDr",
				Cancel);
		EndIf;
	EndDo;

EndProcedure

Procedure CheckStatusBeforeDeletionMark(Cancel)
	
	If DeletionMark And Status = Enums.AccountingEntriesTemplatesStatuses.Active Then
		
		MessageText = NStr("en = 'Cannot mark for deletion the accounting entries template with the Active status.'; ru = 'Не удалось пометить на удаление шаблон бухгалтерских проводок, поскольку его статус – ""Активен"".';pl = 'Nie można zaznaczyć do usunięcia szablonu wpisów księgowych o statusie Aktywny.';es_ES = 'No se puede marcar para su eliminación el modelo de entradas contables con el estado Activo.';es_CO = 'No se puede marcar para su eliminación el modelo de entradas contables con el estado Activo.';tr = 'Aktif durumdaki muhasebe girişleri şablonu silinmek üzere işaretlenemez.';it = 'Impossibile contrassegnare per l''eliminazione il modello di voci di contabilità con stato Attivo.';de = 'Fehler beim Markieren zum Löschen von Vorlagen der Buchungen mit dem Status Aktiv.'");
		DriveServer.ShowMessageAboutError(ThisObject, MessageText, , , , Cancel);
		
	EndIf;
	
EndProcedure

Procedure CheckAnalyticals(Cancel)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	AccountingEntriesTemplatesEntries.LineNumber AS LineNumber,
	|	AccountingEntriesTemplatesEntries.Account AS Account,
	|	AccountingEntriesTemplatesEntries.DrCr AS DrCr,
	|	AccountingEntriesTemplatesEntries.AnalyticalDimensionsSet AS AnalyticalDimensionsSet,
	|	AccountingEntriesTemplatesEntries.AnalyticalDimensionsType1 AS AnalyticalDimensionsType1,
	|	AccountingEntriesTemplatesEntries.AnalyticalDimensionsType2 AS AnalyticalDimensionsType2,
	|	AccountingEntriesTemplatesEntries.AnalyticalDimensionsType3 AS AnalyticalDimensionsType3,
	|	AccountingEntriesTemplatesEntries.AnalyticalDimensionsType4 AS AnalyticalDimensionsType4
	|INTO EntriesTable
	|FROM
	|	&Entries AS AccountingEntriesTemplatesEntries
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	EntriesTable.LineNumber AS LineNumber,
	|	EntriesTable.Account AS Account,
	|	EntriesTable.DrCr AS DrCr,
	|	EntriesTable.AnalyticalDimensionsSet AS AnalyticalDimensionsSet,
	|	EntriesTable.AnalyticalDimensionsType1 AS AnalyticalDimensionsType1,
	|	EntriesTable.AnalyticalDimensionsType2 AS AnalyticalDimensionsType2,
	|	EntriesTable.AnalyticalDimensionsType3 AS AnalyticalDimensionsType3,
	|	EntriesTable.AnalyticalDimensionsType4 AS AnalyticalDimensionsType4
	|FROM
	|	EntriesTable AS EntriesTable
	|		INNER JOIN ChartOfAccounts.MasterChartOfAccounts AS MasterChartOfAccounts
	|		ON EntriesTable.Account = MasterChartOfAccounts.Ref
	|WHERE
	|	VALUETYPE(EntriesTable.Account) = TYPE(ChartOfAccounts.MasterChartOfAccounts)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MasterChartOfAccountsAnalyticalDimensions.AnalyticalDimension AS AnalyticalDimension,
	|	EntriesTable.Account AS Account,
	|	MAX(MasterChartOfAccountsAnalyticalDimensions.LineNumber) AS LineNumber
	|FROM
	|	EntriesTable AS EntriesTable
	|		LEFT JOIN ChartOfAccounts.MasterChartOfAccounts.AnalyticalDimensions AS MasterChartOfAccountsAnalyticalDimensions
	|		ON EntriesTable.Account = MasterChartOfAccountsAnalyticalDimensions.Ref
	|
	|GROUP BY
	|	EntriesTable.Account,
	|	MasterChartOfAccountsAnalyticalDimensions.AnalyticalDimension";
	
	Query.SetParameter("Entries", Entries.Unload( ,"LineNumber, Account, Quantity, Currency, AmountCur, AnalyticalDimensionsSet,
		|AnalyticalDimensionsType1, AnalyticalDimensionsType2, AnalyticalDimensionsType3, AnalyticalDimensionsType4, DrCr"));
	
	ArrayResult = Query.ExecuteBatch();
	
	SelectionDetailRecords = ArrayResult[1].Select();
	
	AnalyticalDimensions = ArrayResult[2].Unload();
	AnalyticalDimensions.Indexes.Add("LineNumber, Account");
	
	MaxAnalyticalDimensionsNumber = WorkWithArbitraryParametersServerCall.MaxAnalyticalDimensionsNumber();
	
	While SelectionDetailRecords.Next() Do
		
		CheckAccount = TypeOf(SelectionDetailRecords.Account) = Type("ChartOfAccountsRef.MasterChartOfAccounts");
		
		If CheckAccount Then
			
			For Index = 1 To MaxAnalyticalDimensionsNumber Do
				
				SelectionLine = New Structure("LineNumber, Account", Index, SelectionDetailRecords.Account);
				FoundExtDimensionsRow = AnalyticalDimensions.FindRows(SelectionLine);
				AnalyticalDimensionsType = SelectionDetailRecords["AnalyticalDimensionsType"+Index];
				AccountAnalyticalDimensionsType = ?(FoundExtDimensionsRow.Count() = 0, 
					ChartsOfCharacteristicTypes.ManagerialAnalyticalDimensionTypes.EmptyRef(), FoundExtDimensionsRow[0].AnalyticalDimension);
				
				If AnalyticalDimensionsType <> AccountAnalyticalDimensionsType Then
					
					ErrorTemplate 	= NStr("en = 'Cannot save the changes. Line %1 contains %2 analytical dimension %3 of type %4
						|that does not match analytical dimension %3 of analytical dimensions set %5'; 
						|ru = 'Не удалось сохранить изменения. Строка %1 содержит %2 аналитическое измерение %3 типа %4 
						|, которое не соответствует аналитическому измерению %3 набора аналитических измерений %5';
						|pl = 'Nie można zapisać zmian. Wiersz %1 zawiera %2 wymiar analityczny %3 o typie %4
						|, który nie jest zgodny z wymiarem analitycznym %3 zestawu wymiarów analitycznych %5';
						|es_ES = 'No se pueden guardar los cambios.La línea %1 contiene %2 la dimensión analítica %3 del tipo %4
						|que no coincide con la dimensión analítica %3 del conjunto de dimensiones analíticas %5';
						|es_CO = 'No se pueden guardar los cambios.La línea %1 contiene %2 la dimensión analítica %3 del tipo %4
						|que no coincide con la dimensión analítica %3 del conjunto de dimensiones analíticas %5';
						|tr = 'Değişiklikler kaydedilemiyor. %1 satırının içerdiği %4 türündeki %2 analitik boyutu %3
						|%5 analitik boyut kümesinin %3 analitik boyutu ile eşleşmiyor';
						|it = 'Impossibile salvare le modifiche. La riga %1 contiene%2 una dimensione analitica %3 di tipo %4
						|che non corrisponde alla dimensione analitica %3 del set di dimensioni analitiche %5';
						|de = 'Fehler beim Speichern von Änderungen. Die Zeile %1 enthält %2analytische Messung %3des Typs %4
						| der mit der analytischen Messung %3 des Satzes analytischer Messungen nicht übereinstimmt%5'");
					ErrorMessage 	= StrTemplate(ErrorTemplate,
						SelectionDetailRecords.LineNumber,
						Lower(String(SelectionDetailRecords.DrCr)),
						Index,
						AnalyticalDimensionsType,
						SelectionDetailRecords.AnalyticalDimensionsSet);
					DriveServer.ShowMessageAboutError(ThisObject, ErrorMessage, "EntriesSimple", SelectionDetailRecords.LineNumber, "AnalyticalDimensionsTypeCr"+Index, Cancel);
		
				EndIf;
				
			EndDo;
			
		EndIf;

	EndDo;

EndProcedure

Procedure CheckAnalyticalsSimple(Cancel)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	AccountingEntriesTemplatesEntries.LineNumber AS LineNumber,
	|	AccountingEntriesTemplatesEntries.AccountCr AS AccountCr,
	|	AccountingEntriesTemplatesEntries.AccountDr AS AccountDr,
	|	AccountingEntriesTemplatesEntries.AnalyticalDimensionsSetCr AS AnalyticalDimensionsSetCr,
	|	AccountingEntriesTemplatesEntries.AnalyticalDimensionsSetDr AS AnalyticalDimensionsSetDr,
	|	AccountingEntriesTemplatesEntries.AnalyticalDimensionsTypeCr1 AS AnalyticalDimensionsTypeCr1,
	|	AccountingEntriesTemplatesEntries.AnalyticalDimensionsTypeCr2 AS AnalyticalDimensionsTypeCr2,
	|	AccountingEntriesTemplatesEntries.AnalyticalDimensionsTypeCr3 AS AnalyticalDimensionsTypeCr3,
	|	AccountingEntriesTemplatesEntries.AnalyticalDimensionsTypeCr4 AS AnalyticalDimensionsTypeCr4,
	|	AccountingEntriesTemplatesEntries.AnalyticalDimensionsTypeDr1 AS AnalyticalDimensionsTypeDr1,
	|	AccountingEntriesTemplatesEntries.AnalyticalDimensionsTypeDr2 AS AnalyticalDimensionsTypeDr2,
	|	AccountingEntriesTemplatesEntries.AnalyticalDimensionsTypeDr3 AS AnalyticalDimensionsTypeDr3,
	|	AccountingEntriesTemplatesEntries.AnalyticalDimensionsTypeDr4 AS AnalyticalDimensionsTypeDr4
	|INTO EntriesTable
	|FROM
	|	&EntriesSimple AS AccountingEntriesTemplatesEntries
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	EntriesTable.LineNumber AS LineNumber,
	|	EntriesTable.AccountCr AS AccountCr,
	|	EntriesTable.AccountDr AS AccountDr,
	|	EntriesTable.AnalyticalDimensionsSetCr AS AnalyticalDimensionsSetCr,
	|	EntriesTable.AnalyticalDimensionsSetDr AS AnalyticalDimensionsSetDr,
	|	EntriesTable.AnalyticalDimensionsTypeCr1 AS AnalyticalDimensionsTypeCr1,
	|	EntriesTable.AnalyticalDimensionsTypeCr2 AS AnalyticalDimensionsTypeCr2,
	|	EntriesTable.AnalyticalDimensionsTypeCr3 AS AnalyticalDimensionsTypeCr3,
	|	EntriesTable.AnalyticalDimensionsTypeCr4 AS AnalyticalDimensionsTypeCr4,
	|	EntriesTable.AnalyticalDimensionsTypeDr1 AS AnalyticalDimensionsTypeDr1,
	|	EntriesTable.AnalyticalDimensionsTypeDr2 AS AnalyticalDimensionsTypeDr2,
	|	EntriesTable.AnalyticalDimensionsTypeDr3 AS AnalyticalDimensionsTypeDr3,
	|	EntriesTable.AnalyticalDimensionsTypeDr4 AS AnalyticalDimensionsTypeDr4
	|FROM
	|	EntriesTable AS EntriesTable
	|		LEFT JOIN ChartOfAccounts.MasterChartOfAccounts AS MasterChartOfAccountsCr
	|		ON EntriesTable.AccountCr = MasterChartOfAccountsCr.Ref
	|		LEFT JOIN ChartOfAccounts.MasterChartOfAccounts AS MasterChartOfAccountsDr
	|		ON EntriesTable.AccountDr = MasterChartOfAccountsDr.Ref
	|WHERE
	|	(VALUETYPE(EntriesTable.AccountCr) = TYPE(ChartOfAccounts.MasterChartOfAccounts)
	|			OR VALUETYPE(EntriesTable.AccountDr) = TYPE(ChartOfAccounts.MasterChartOfAccounts))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MasterChartOfAccountsAnalyticalDimensions.AnalyticalDimension AS AnalyticalDimension,
	|	EntriesTable.AccountCr AS Account,
	|	MAX(MasterChartOfAccountsAnalyticalDimensions.LineNumber) AS LineNumber
	|FROM
	|	EntriesTable AS EntriesTable
	|		LEFT JOIN ChartOfAccounts.MasterChartOfAccounts.AnalyticalDimensions AS MasterChartOfAccountsAnalyticalDimensions
	|		ON EntriesTable.AccountCr = MasterChartOfAccountsAnalyticalDimensions.Ref
	|
	|GROUP BY
	|	EntriesTable.AccountCr,
	|	MasterChartOfAccountsAnalyticalDimensions.AnalyticalDimension
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MasterChartOfAccountsAnalyticalDimensions.AnalyticalDimension AS AnalyticalDimension,
	|	EntriesTable.AccountDr AS Account,
	|	MAX(MasterChartOfAccountsAnalyticalDimensions.LineNumber) AS LineNumber
	|FROM
	|	EntriesTable AS EntriesTable
	|		LEFT JOIN ChartOfAccounts.MasterChartOfAccounts.AnalyticalDimensions AS MasterChartOfAccountsAnalyticalDimensions
	|		ON EntriesTable.AccountDr = MasterChartOfAccountsAnalyticalDimensions.Ref
	|
	|GROUP BY
	|	MasterChartOfAccountsAnalyticalDimensions.AnalyticalDimension,
	|	EntriesTable.AccountDr";
	
	Query.SetParameter("EntriesSimple", EntriesSimple.Unload(, "LineNumber, AccountCr, AccountDr, QuantityCr, QuantityDr,
		|CurrencyCr, CurrencyDr , AmountCurDr, AmountCurCr, AnalyticalDimensionsSetCr, AnalyticalDimensionsSetDr,
		|AnalyticalDimensionsTypeCr1, AnalyticalDimensionsTypeCr2, AnalyticalDimensionsTypeCr3, AnalyticalDimensionsTypeCr4,
		|AnalyticalDimensionsTypeDr1, AnalyticalDimensionsTypeDr2, AnalyticalDimensionsTypeDr3, AnalyticalDimensionsTypeDr4"));
	
	ArrayResult = Query.ExecuteBatch();
	
	SelectionDetailRecords = ArrayResult[1].Select();
	
	AnalyticalDimensionsCr = ArrayResult[2].Unload();
	AnalyticalDimensionsCr.Indexes.Add("LineNumber, Account");
	
	AnalyticalDimensionsDr = ArrayResult[3].Unload();
	AnalyticalDimensionsDr.Indexes.Add("LineNumber, Account");
	
	MaxAnalyticalDimensionsNumber = WorkWithArbitraryParametersServerCall.MaxAnalyticalDimensionsNumber();
	
	While SelectionDetailRecords.Next() Do
		
		CheckCrAccount = TypeOf(SelectionDetailRecords.AccountCr) = Type("ChartOfAccountsRef.MasterChartOfAccounts");
		CheckDrAccount = TypeOf(SelectionDetailRecords.AccountDr) = Type("ChartOfAccountsRef.MasterChartOfAccounts");
		
		For Index = 1 To MaxAnalyticalDimensionsNumber Do
			
			// Credit
			If CheckCrAccount Then
				SelectionLine = New Structure("LineNumber, Account", Index, SelectionDetailRecords.AccountCr);
				FoundExtDimensionsRow = AnalyticalDimensionsCr.FindRows(SelectionLine);
				AnalyticalDimensionsType = SelectionDetailRecords["AnalyticalDimensionsTypeCr"+Index];
				AccountAnalyticalDimensionsType = ?(FoundExtDimensionsRow.Count() = 0, 
					ChartsOfCharacteristicTypes.ManagerialAnalyticalDimensionTypes.EmptyRef(), FoundExtDimensionsRow[0].AnalyticalDimension);
				
				If AnalyticalDimensionsType <> AccountAnalyticalDimensionsType Then
					
					ErrorTemplate 	= NStr("en = 'Cannot save the changes. Line %1 contains %2 analytical dimension %3 of type %4
						|that does not match analytical dimension %3 of analytical dimensions set %5'; 
						|ru = 'Не удалось сохранить изменения. Строка %1 содержит %2 аналитическое измерение %3 типа %4 
						|, которое не соответствует аналитическому измерению %3 набора аналитических измерений %5';
						|pl = 'Nie można zapisać zmian. Wiersz %1 zawiera %2 wymiar analityczny %3 o typie %4
						|, który nie jest zgodny z wymiarem analitycznym %3 zestawu wymiarów analitycznych %5';
						|es_ES = 'No se pueden guardar los cambios.La línea %1 contiene %2 la dimensión analítica %3 del tipo %4
						|que no coincide con la dimensión analítica %3 del conjunto de dimensiones analíticas %5';
						|es_CO = 'No se pueden guardar los cambios.La línea %1 contiene %2 la dimensión analítica %3 del tipo %4
						|que no coincide con la dimensión analítica %3 del conjunto de dimensiones analíticas %5';
						|tr = 'Değişiklikler kaydedilemiyor. %1 satırının içerdiği %4 türündeki %2 analitik boyutu %3
						|%5 analitik boyut kümesinin %3 analitik boyutu ile eşleşmiyor';
						|it = 'Impossibile salvare le modifiche. La riga %1 contiene%2 una dimensione analitica %3 di tipo %4
						|che non corrisponde alla dimensione analitica %3 del set di dimensioni analitiche %5';
						|de = 'Fehler beim Speichern von Änderungen. Die Zeile %1 enthält %2analytische Messung %3des Typs %4
						| der mit der analytischen Messung %3 des Satzes analytischer Messungen nicht übereinstimmt%5'");
					ErrorMessage 	= StrTemplate(ErrorTemplate,
						SelectionDetailRecords.LineNumber,
						NStr("en = 'credit'; ru = 'кредит';pl = 'Należności';es_ES = 'crédito';es_CO = 'crédito';tr = 'alacak';it = 'credito';de = 'Haben'"),
						Index,
						AnalyticalDimensionsType,
						SelectionDetailRecords.AnalyticalDimensionsSetCr);
					DriveServer.ShowMessageAboutError(ThisObject, ErrorMessage, "EntriesSimple", SelectionDetailRecords.LineNumber, "AnalyticalDimensionsTypeCr"+Index, Cancel);
		
				EndIf;
			EndIf;
			
			// Debit
			If CheckDrAccount Then
				SelectionLine = New Structure("LineNumber, Account", Index, SelectionDetailRecords.AccountDr);
				FoundExtDimensionsRow = AnalyticalDimensionsDr.FindRows(SelectionLine);
				AnalyticalDimensionsType = SelectionDetailRecords["AnalyticalDimensionsTypeDr"+Index];
				AccountAnalyticalDimensionsType = ?(FoundExtDimensionsRow.Count() = 0, 
					ChartsOfCharacteristicTypes.ManagerialAnalyticalDimensionTypes.EmptyRef(), FoundExtDimensionsRow[0].AnalyticalDimension);
				
				If AnalyticalDimensionsType <> AccountAnalyticalDimensionsType Then
					
					ErrorTemplate 	= NStr("en = 'Cannot save the changes. Line %1 contains %2 analytical dimension %3 of type %4
						|that does not match analytical dimension %3 of analytical dimensions set %5'; 
						|ru = 'Не удалось сохранить изменения. Строка %1 содержит %2 аналитическое измерение %3 типа %4 
						|, которое не соответствует аналитическому измерению %3 набора аналитических измерений %5';
						|pl = 'Nie można zapisać zmian. Wiersz %1 zawiera %2 wymiar analityczny %3 o typie %4
						|, który nie jest zgodny z wymiarem analitycznym %3 zestawu wymiarów analitycznych %5';
						|es_ES = 'No se pueden guardar los cambios.La línea %1 contiene %2 la dimensión analítica %3 del tipo %4
						|que no coincide con la dimensión analítica %3 del conjunto de dimensiones analíticas %5';
						|es_CO = 'No se pueden guardar los cambios.La línea %1 contiene %2 la dimensión analítica %3 del tipo %4
						|que no coincide con la dimensión analítica %3 del conjunto de dimensiones analíticas %5';
						|tr = 'Değişiklikler kaydedilemiyor. %1 satırının içerdiği %4 türündeki %2 analitik boyutu %3
						|%5 analitik boyut kümesinin %3 analitik boyutu ile eşleşmiyor';
						|it = 'Impossibile salvare le modifiche. La riga %1 contiene%2 una dimensione analitica %3 di tipo %4
						|che non corrisponde alla dimensione analitica %3 del set di dimensioni analitiche %5';
						|de = 'Fehler beim Speichern von Änderungen. Die Zeile %1 enthält %2analytische Messung %3des Typs %4
						| der mit der analytischen Messung %3 des Satzes analytischer Messungen nicht übereinstimmt%5'");
					ErrorMessage 	= StrTemplate(ErrorTemplate,
						SelectionDetailRecords.LineNumber,
						NStr("en = 'debit'; ru = 'дебет';pl = 'Zobowiązania';es_ES = 'débito';es_CO = 'débito';tr = 'borç';it = 'debito';de = 'Soll'"),
						Index,
						AnalyticalDimensionsType,
						SelectionDetailRecords.AnalyticalDimensionsSetDr);
					DriveServer.ShowMessageAboutError(ThisObject, ErrorMessage, "EntriesSimple", SelectionDetailRecords.LineNumber, "AnalyticalDimensionsTypeCr"+Index, Cancel);
		
				EndIf;
			EndIf;
		EndDo;

	EndDo;

EndProcedure

#EndRegion

Procedure CheckSubordinateTemplates(Cancel)
	
	SubordTemplStructure = Catalogs.AccountingEntriesTemplates.CheckSubordinateTemplates(ThisObject);

	ModifiedAttributes = DriveServer.GetModifiedAttributes(ThisObject);
	
	SubordTemplStructure.Insert("ModifiedContent", ModifiedAttributes.Count() = 1
		And (ModifiedAttributes[0] = "EntriesSimple.Content" Or ModifiedAttributes[0] = "Entries.Content"));
		
	If SubordTemplStructure.IsActive
		And SubordTemplStructure.IsUsed Then
		
		Cancel = True;
		
		ErrorTemplate = NStr("en = '%1, {%2} is used in Accounting transaction template {%3} with the %4 status.'; ru = '%1, {%2} используется в шаблоне бухгалтерских операций {%3} со статусом %4.';pl = '%1, {%2} jest używana w szablonie transakcji księgowej {%3} o statusie %4.';es_ES = '%1, {%2} se utiliza en la plantilla de Transacción contable {%3} con el estado %4.';es_CO = '%1, {%2} se utiliza en la plantilla de Transacción contable {%3} con el estado %4.';tr = '%1, {%2} durumu %4 olan {%3} Muhasebe işlemi şablonunda kullanılıyor.';it = '%1, {%2} è utilizzato nel modello di transazione di contabilità {%3} con stato %4.';de = '%1, {%2} ist in Vorlage von Buchhaltungstransaktion {%3} mit dem Status %4 verwendet.'");
		
		For Each UsedTemplate In SubordTemplStructure.TemplatesArray Do
			
			If UsedTemplate.Active Then
				StatusText = NStr("en = 'Active'; ru = 'Активен';pl = 'Aktywny';es_ES = 'Activo';es_CO = 'Activo';tr = 'Aktif';it = 'Attivo';de = 'Aktiv'");
				
				ErrMessage = StrTemplate(ErrorTemplate, Description, Code, UsedTemplate.Code, StatusText);
				CommonClientServer.MessageToUser(ErrMessage, UsedTemplate.Ref);
			EndIf;
			
		EndDo;

	ElsIf SubordTemplStructure.IsActive
		And SubordTemplStructure.IsPeriodMatch Then
			
		Cancel = True;
		
		ErrorTemplate = NStr("en = 'Accounting entries template {%1}: new template validity period {%2} 
			|does not match the validity period {%3} of the Accounting transaction template {%4} with the %5 status.'; 
			|ru = 'Шаблон бухгалтерских проводок {%1}: новый срок действия шаблона {%2} 
			|не соответствует сроку действия {%3} шаблона бухгалтерских операций {%4} со статусом %5.';
			|pl = 'Szablon wpisów księgowych {%1}: okres ważności nowego szablonu {%2} 
			|nie jest zgodny z okresem ważności {%3} szablonu Transakcji księgowej {%4} o statusie %5.';
			|es_ES = 'Plantilla de entradas contables {%1}: el nuevo periodo de validez de la plantilla {%2} 
			|no coincide con el periodo de validez {%3} de la plantilla de Transacción contable {%4} con el estado %5.';
			|es_CO = 'Plantilla de entradas contables {%1}: el nuevo periodo de validez de la plantilla {%2} 
			|no coincide con el periodo de validez {%3} de la plantilla de Transacción contable {%4} con el estado %5.';
			|tr = 'Muhasebe girişi şablonu {%1}: Yeni şablon geçerlilik dönemi {%2} 
			|%5 durumlu {%4} Muhasebe işlem şablonunun {%3} geçerlilik dönemi ile eşleşmiyor.';
			|it = 'Modello di voci di contabilità {%1}: nuovo periodo di validità del modello {%2}
			| non corrispondente al periodo di validità {%3}del modello di transazione di contabilità{%4} con stato %5.';
			|de = 'Vorlage von Buchungen {%1}: neue Gültigkeitsdauer von Vorlage {%2} 
			| stimmt mit der Gültigkeitsdauer {%3} der Vorlage von Buchhaltungstransaktion {%4} mit dem Status %5 nicht überein.'");
			
		NewPeriodTemplate = StrTemplate("%1 - %2", Format(StartDate, "DLF=D; DE=..."), Format(EndDate, "DLF=D; DE=..."));
		
		For Each NotMatchedPeriod In SubordTemplStructure.TemplatesArray Do
			
			If NotMatchedPeriod.Active Then
				StatusText = NStr("en = 'Active'; ru = 'Активен';pl = 'Aktywny';es_ES = 'Activo';es_CO = 'Activo';tr = 'Aktif';it = 'Attivo';de = 'Aktiv'");
				
				ErrMessage = StrTemplate(ErrorTemplate, Code, NewPeriodTemplate, NotMatchedPeriod.Period, NotMatchedPeriod.Code, StatusText);
				CommonClientServer.MessageToUser(ErrMessage, NotMatchedPeriod.Ref, "PlanStartDate");
			EndIf;
			
		EndDo;
		
	Else
		AdditionalProperties.Insert("ShowSubordinateTemplatesMessage", True);
		AdditionalProperties.Insert("SubordinateTemplatesClearing", True);
	EndIf;
	
EndProcedure

Procedure ClearSubordinateTemplates()
	
	If Not AdditionalProperties.Property("SubordinateTemplatesClearing") 
		Or Not AdditionalProperties.SubordinateTemplatesClearing Then
		
		Return;
		
	EndIf;
	
	If AdditionalProperties.Property("ShowSubordinateTemplatesMessage") 
		And AdditionalProperties.ShowSubordinateTemplatesMessage Then
		ShowMessages = True;
	Else
		ShowMessages = False;
	EndIf;
		
	If Status = Enums.AccountingEntriesTemplatesStatuses.Draft Then
		
		DraftTransTemplTable = Catalogs.AccountingTransactionsTemplates.FindTemplateUsage(
			Ref,
			Enums.AccountingEntriesTemplatesStatuses.Draft);
			
		Catalogs.AccountingTransactionsTemplates.DeleteTemplateUsage(DraftTransTemplTable, ThisObject, ShowMessages);
		
	ElsIf Status = Enums.AccountingEntriesTemplatesStatuses.Active Then
		
		DraftTransTemplTable = Catalogs.AccountingTransactionsTemplates.FindTemplatePeriodsNotMatch(
			Ref,
			Enums.AccountingEntriesTemplatesStatuses.Draft, StartDate, EndDate);
			
		Catalogs.AccountingTransactionsTemplates.DeleteTemplateUsage(DraftTransTemplTable, ThisObject, ShowMessages);
		
	EndIf;
	
EndProcedure

Procedure AccountValidation(Cancel)
	
	ErrorFields = New Array;
	
	WorkWithArbitraryParameters.CheckAccountsValueValidation(ThisObject, ErrorFields);

	WorkWithArbitraryParameters.CheckDefaultAccountValidation(ThisObject, ErrorFields);
	
	ErrorLines = New Array;
	
	If EntriesSimple.Count() > 0 Then
		TableName = "EntriesSimple";
	Else
		TableName = "Entries";
	EndIf;
	
	For Each Field In ErrorFields Do
		
		If Field.Property("RowCount") Then
			
			RowCount = Field.RowCount;
			
			If ErrorLines.Find(RowCount) = Undefined Then
				
				ErrorLines.Add(RowCount);
				LineNumber = RowCount+1;
				
				If Field.Property("DefaultAccount") Then
					ErrorTemplate 	= NStr("en = 'Cannot save the changes. Line %1 contains account %2. This account is not valid for the
						|selected company, types of accounts, or chart of accounts of this template. Select another default account.'; 
						|ru = 'Не удалось сохранить изменения. Строка %1 содержит счет %2. Этот счет недействителен для
						|выбранной организации, типов счетов или плана счетов этого шаблона. Выберите другой счет.';
						|pl = 'Nie można zapisać zmian. Wiersz %1 zawiera konto %2. To konto nie jest ważne dla 
						|wybranej firmy, rodzajów kont tego szablonu. Wybierz inne domyślne konto.';
						|es_ES = 'No se pueden guardar los cambios. La línea %1 contiene la cuenta %2. Esta cuenta no es válida para la 
						|empresa seleccionada, los tipos de cuentas o el diagrama de cuentas de esta plantilla. Seleccione otra cuenta por defecto.';
						|es_CO = 'No se pueden guardar los cambios. La línea %1 contiene la cuenta %2. Esta cuenta no es válida para la 
						|empresa seleccionada, los tipos de cuentas o el diagrama de cuentas de esta plantilla. Seleccione otra cuenta por defecto.';
						|tr = 'Değişiklikler kaydedilemiyor. %1 satırı %2 hesabını içeriyor. Bu hesap bu şablonun seçilen iş yeri, 
						|hesap türleri veya hesap planı için geçerli değil. Başka bir hesap seçin.';
						|it = 'Impossibile salvare le modifiche. La riga %1 contiene il conto %2. Questo conto non è valido per la
						|compagnia selezionata, tipi di conti, o piani dei conti di questo modello. Selezionare un altro conto predefinito.';
						|de = 'Fehler beim Speichern von Änderungen. Die Zeile %1 enthält Konto %2. Dieses Konto ist für die 
						| ausgewählte Firma, Typen von Konten oder das Kontenplan dieser Vorlage nicht gültig. Wählen Sie ein anderes Standardkonto aus.'");
				Else
					ErrorTemplate 	= NStr("en = 'Cannot save the changes. Line %1 contains account %2. This account is not valid for the
						|selected company, chart of accounts, or validity period of this template. Select another account.'; 
						|ru = 'Не удалось сохранить изменения. Строка %1 содержит счет %2. Этот счет недействителен для
						|выбранной организации, плана счетов или срока действия этого шаблона. Выберите другой счет.';
						|pl = 'Nie można zapisać zmian. Wiersz %1 zawiera konto %2. To konto nie jest ważne dla 
						|wybranej firmy, planu kont tego szablonu. Wybierz inne konto.';
						|es_ES = 'No se pueden guardar los cambios. La línea %1 contiene la cuenta%2. Esta cuenta no es válida para la
						|empresa seleccionada, el diagrama de cuentas o el periodo de validez de este modelo. Seleccione otra cuenta.';
						|es_CO = 'No se pueden guardar los cambios. La línea %1 contiene la cuenta%2. Esta cuenta no es válida para la
						|empresa seleccionada, el diagrama de cuentas o el periodo de validez de este modelo. Seleccione otra cuenta.';
						|tr = 'Değişiklikler kaydedilemiyor. %1 satırı %2 hesabını içeriyor. Bu hesap seçilen iş yeri, hesap planı 
						|veya bu şablonun geçerlilik dönemi için geçerli değil. Başka bir hesap seçin.';
						|it = 'Impossibile salvare le modifiche. La riga %1 contiene il conto %2. Questo conto non è valido per 
						|l''azienda selezionata, piano dei conti o periodo di validità di questo modello. Selezionare un altro conto.';
						|de = 'Fehler beim Speichern von Änderungen. Die Zeile %1 enthält Konto %2. Dieses Konto ist für die 
						| ausgewählte Firma, das Kontenplan oder die Gültigkeitsdauer dieser Vorlage nicht gültig. Wählen Sie ein anderes Standardkonto aus.'");
				EndIf;	
				
				ErrorMessage = StrTemplate(ErrorTemplate,
				LineNumber,
				?(Field.Property("DefaultAccount"), ErrorFields[0].Synonym, ErrorFields[0].Synonym.Description));
				
				DriveServer.ShowMessageAboutError(ThisObject, ErrorMessage, TableName, LineNumber, StrReplace(Field.Name, "Synonym", ""), Cancel);
				
			EndIf;
			
		EndIf;
		
	EndDo;

EndProcedure

#EndRegion

#EndIf