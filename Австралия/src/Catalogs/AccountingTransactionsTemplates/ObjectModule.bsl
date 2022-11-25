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
		
	If Status = Enums.AccountingEntriesTemplatesStatuses.Draft Then
		CheckedAttributes.Clear();
		
	ElsIf Status = Enums.AccountingEntriesTemplatesStatuses.Active Then
		
		If DeletionMark Then 
			ErrorMessage = NStr("en = 'Cannot save changes. This template is marked for deletion.'; ru = 'Не удалось сохранить изменения. Шаблон помечен на удаление.';pl = 'Nie można zapisać zmian. Ten szablon jest zaznaczony do usunięcia.';es_ES = 'No se pueden guardar los cambios. Esta plantilla está marcada para ser eliminada.';es_CO = 'No se pueden guardar los cambios. Esta plantilla está marcada para ser eliminada.';tr = 'Değişiklikler kaydedilemiyor. Bu şablon silinmek üzere işaretlenmiş.';it = 'Impossibile salvare le modifiche. Questo modello è contrassegnato per l''eliminazione.';de = 'Fehler beim Speichern von Änderungen. Diese Vorlage ist zum Löschen markiert.'");
			DriveServer.ShowMessageAboutError(ThisObject, ErrorMessage, , , , Cancel);
		EndIf;
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PlanStartDate");
		
		If ValueIsFilled(EndDate) And EndDate < StartDate Then
			ErrorMessage = NStr("en = '""To"" date must be equal to or later than ""From"" date. Edit ""To"" date, then try again.'; ru = 'Дата в поле ""По"" не может быть меньше даты в поле ""С"". Отредактируйте дату в поле ""По"" и повторите попытку.';pl = 'Data ""Do"" powinna być równa lub późniejsza niż data ""Od"". Edytuj datę ""Do"", następnie spróbuj ponownie.';es_ES = 'La fecha ""Hasta"" debe ser igual o posterior a la fecha ""Desde"". Edite la fecha ""Hasta"" y vuelva a intentarlo.';es_CO = 'La fecha ""Hasta"" debe ser igual o posterior a la fecha ""Desde"". Edite la fecha ""Hasta"" y vuelva a intentarlo.';tr = '""Bitiş"" tarihi ""Başlangıç"" tarihi ile aynı veya daha sonra olmalıdır. ""Bitiş"" tarihini değiştirip tekrar deneyin.';it = 'La data ""fino a"" deve essere uguale o successiva alla data ""Da"". Modificare la data ""fino a"", poi riprovare.';de = '""Bis zu"" muss gleich oder später als Datum ""Von "" liegen. Bearbeiten Sie das Datum ""Bis zum"", dann versuchen Sie erneut.'");
			DriveServer.ShowMessageAboutError(ThisObject, ErrorMessage, , , "EndDate", Cancel);
		EndIf;
		
		EntriesTemplatesRefs = GetEntriesRefs();
		EntriesTemplatesMap	 = GetEntriesRefsMap();
		ActiveTSName		 = ?(Entries.Count() > 0, "Entries", "EntriesSimple");
		
		CheckParametersFilling(Cancel);
		CheckDrCrFilling(Cancel);
		CheckTemplatesAttributes(Cancel, EntriesTemplatesRefs, EntriesTemplatesMap, ActiveTSName);
		CheckTemplatesActiveStatus(Cancel, EntriesTemplatesRefs, EntriesTemplatesMap, ActiveTSName);
		CheckTemplatesPeriods(Cancel);
		
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
		ElemRef = Catalogs.AccountingTransactionsTemplates.GetRef();
		SetNewObjectRef(ElemRef);
	Else
		ElemRef = Ref;
		
		NewTemplateParameters = New Structure("Status, StartDate, EndDate");
		FillPropertyValues(NewTemplateParameters, ThisObject);
		
		If Catalogs.AccountingTransactionsTemplates.AreEntriesWithTemplate(Ref, NewTemplateParameters) Then
			
			MessageText = NStr("en = 'Cannot change the template status. This template is already applied to accounting entries.'; ru = 'Не удалось изменить статус шаблона. Этот шаблон уже применяется к бухгалтерским проводкам.';pl = 'Nie można zmienić statusu szablonu. Ten szablon jest już zastosowany do wpisów księgowych.';es_ES = 'No se puede cambiar el estado de la plantilla. Esta plantilla ya se aplica a las entradas contables.';es_CO = 'No se puede cambiar el estado de la plantilla. Esta plantilla ya se aplica a las entradas contables.';tr = 'Şablon durumu değiştirilemiyor. Bu şablon muhasebe girişlerine uygulanmış durumda.';it = 'Impossibile modificare lo stato del modello. Questo modello è già applicato alle voci di contabilità.';de = 'Fehler beim Ändern des Status der Vorlage. Diese Vorlage ist für Buchungen bereits verwendet.'");
			CommonClientServer.MessageToUser(MessageText, Ref, "Object.Status", , Cancel);
			Return;
			
		EndIf;
		
		If Status = Enums.AccountingEntriesTemplatesStatuses.Draft 
			And Status <> Common.ObjectAttributeValue(Ref, "Status") Then
			
			PlanStartDate = Common.ObjectAttributeValue(Ref, "StartDate");
			
		EndIf;
	EndIf;
	
	CheckStatusBeforeDeletionMark(Cancel);
	
	If Not Cancel Then
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
		Description = StrTemplate("%1: %2 (%3)", DocumentTypeSynonym, TypeOfAccounting, ChartOfAccounts);		
	EndIf;

EndProcedure

Procedure CheckParametersFilling(Cancel)
		
	Query = New Query;
	Query.Text = 
	"SELECT
	|	TemplatesParameters.ParameterName AS ParameterName,
	|	TemplatesParameters.LineNumber AS LineNumber,
	|	TemplatesParameters.LineNumber AS LineNumber1
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
	|	COUNT(DISTINCT ParametersTable.LineNumber1) > 1";
	
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
	
	If Common.ObjectAttributeValue(ChartOfAccounts, "TypeOfEntries") = Enums.ChartsOfAccountsTypesOfEntries.Compound Then
		Return;
	EndIf;
	
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
	|	MAX(EntriesTable.LineNumber) AS LineNumber,
	|	EntriesTable.EntryNumber AS EntryNumber
	|FROM
	|	EntriesTable AS EntriesTable
	|
	|GROUP BY
	|	EntriesTable.EntryNumber,
	|	EntriesTable.DrCr
	|
	|HAVING
	|	COUNT(DISTINCT EntriesTable.DrCr) <> 2";
	
	Query.SetParameter("Entries", Entries.Unload( ,"LineNumber, EntryNumber, DrCr"));
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	Cancel = Not QueryResult.IsEmpty();
	
EndProcedure

Procedure CheckTemplatesAttributes(Cancel, EntriesTemplatesRefs, EntriesTemplatesMap, ActiveTSName)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	AccountingEntriesTemplates.Presentation AS RefPresentation,
	|	&CompanyField AS ErrorField,
	|	AccountingEntriesTemplates.Code AS Code,
	|	AccountingEntriesTemplates.Ref AS Ref
	|FROM
	|	Catalog.AccountingEntriesTemplates AS AccountingEntriesTemplates
	|WHERE
	|	AccountingEntriesTemplates.Ref IN(&EntriesTemplatesRefs)
	|	AND NOT AccountingEntriesTemplates.Company IN (&Company, VALUE(Catalog.Companies.EmptyRef))
	|
	|UNION ALL
	|
	|SELECT
	|	AccountingEntriesTemplates.Ref.Presentation,
	|	&TypeOfAccountingField,
	|	AccountingEntriesTemplates.Code,
	|	AccountingEntriesTemplates.Ref
	|FROM
	|	Catalog.AccountingEntriesTemplates AS AccountingEntriesTemplates
	|WHERE
	|	AccountingEntriesTemplates.Ref IN(&EntriesTemplatesRefs)
	|	AND AccountingEntriesTemplates.TypeOfAccounting <> &TypeOfAccounting
	|
	|UNION ALL
	|
	|SELECT
	|	AccountingEntriesTemplates.Ref.Presentation,
	|	&ChartOfAccountsField,
	|	AccountingEntriesTemplates.Code,
	|	AccountingEntriesTemplates.Ref
	|FROM
	|	Catalog.AccountingEntriesTemplates AS AccountingEntriesTemplates
	|WHERE
	|	AccountingEntriesTemplates.Ref IN(&EntriesTemplatesRefs)
	|	AND AccountingEntriesTemplates.ChartOfAccounts <> &ChartOfAccounts
	|
	|UNION ALL
	|
	|SELECT
	|	AccountingEntriesTemplates.Ref.Presentation,
	|	&DocumentTypeField,
	|	AccountingEntriesTemplates.Code,
	|	AccountingEntriesTemplates.Ref
	|FROM
	|	Catalog.AccountingEntriesTemplates AS AccountingEntriesTemplates
	|WHERE
	|	AccountingEntriesTemplates.Ref IN(&EntriesTemplatesRefs)
	|	AND AccountingEntriesTemplates.DocumentType <> &DocumentType
	|TOTALS BY
	|	ErrorField";
	
	Query.SetParameter("ChartOfAccounts"		, ChartOfAccounts);
	Query.SetParameter("Company"				, Company);
	Query.SetParameter("DocumentType"			, DocumentType);
	Query.SetParameter("TypeOfAccounting"		, TypeOfAccounting);
	Query.SetParameter("EntriesTemplatesRefs"	, GetEntriesRefs());
	Query.SetParameter("ChartOfAccountsField"	, NStr("en = 'Chart of accounts'; ru = 'План счетов';pl = 'Plan kont';es_ES = 'Diagrama primario de las cuentas';es_CO = 'Diagrama primario de las cuentas';tr = 'Hesap planı';it = 'Piano dei conti';de = 'Kontenplan'"));
	Query.SetParameter("CompanyField"			, NStr("en = 'Company'; ru = 'Организация';pl = 'Firma';es_ES = 'Empresa';es_CO = 'Empresa';tr = 'İş yeri';it = 'Azienda';de = 'Firma'"));
	Query.SetParameter("DocumentTypeField"		, NStr("en = 'Document type'; ru = 'Тип документа';pl = 'Typ dokumentu';es_ES = 'Tipo de documento';es_CO = 'Tipo de documento';tr = 'Belge türü';it = 'Tipo di documento';de = 'Dokumententyp'"));
	Query.SetParameter("TypeOfAccountingField"	, NStr("en = 'Type of accounting'; ru = 'Тип бухгалтерского учета';pl = 'Typ rachunkowości';es_ES = 'Tipo de contabilidad';es_CO = 'Tipo de contabilidad';tr = 'Muhasebe türü';it = 'Tipo di contabilità';de = 'Typ der Buchhaltung'"));
	
	QueryResult = Query.Execute();
	
	SelectionErrorField = QueryResult.Select(QueryResultIteration.ByGroups);
	
	While SelectionErrorField.Next() Do
	
		Selection = SelectionErrorField.Select();
	
		While Selection.Next() Do
			
			ErrorTemplate = NStr("en = 'Cannot save the template. It includes entry template %2 (%3).  
				|In these templates, the values of the ""%1"" field do not match. 
				|Edit the field in either of the templates. 
				|Then try again.'; 
				|ru = 'Не удалось сохранить шаблон. Он включает в себя шаблон проводок %2 (%3). 
				|В этих шаблонах не совпадают значения поля ""%1"". 
				|Отредактируйте поле в любом из шаблонов и повторите попытку.';
				|pl = 'Nie można zapisać szablonu. Obejmuje on szablon wpisu %2 (%3). 
				|W tych szablonach, wartości pola ""%1"" nie są zgodne. 
				|Edytuj pole w jednym z szablonów. 
				|Zatem spróbuj ponownie.';
				|es_ES = 'No se puede guardar la plantilla. Incluye plantilla de entrada %2 (%3). 
				|En estas plantillas, los valores del ""%1"" campo no coinciden. 
				|Edite el campo en cualquiera de las plantillas. 
				|Inténtelo de nuevo.';
				|es_CO = 'No se puede guardar la plantilla. Incluye plantilla de entrada %2 (%3). 
				|En estas plantillas, los valores del ""%1"" campo no coinciden. 
				|Edite el campo en cualquiera de las plantillas. 
				|Inténtelo de nuevo.';
				|tr = 'Şablon kaydedilemiyor. %2 (%3) giriş şablonunu içeriyor. 
				|Bu şablonlarda, ""%1"" alanının değerleri eşleşmiyor. 
				|Şablonlardan birinde alanı düzenleyin. 
				|Ardından, tekrar deneyin.';
				|it = 'Impossibile salvare il modello. Contiene modello di voce %2 (%3). 
				|In questi modelli, i valori del campo ""%1"" non corrispondono.
				|Modificare il campo in uno dei modelli, 
				|poi riprovare.';
				|de = 'Fehler beim Speichern der Vorlage. Sie enthält Buchungsvorlagen %2 (%3). 
				|In diesen Vorlagen stimmen die Werte des Felds ""%1"" nicht überein. 
				|Bearbeiten Sie das Feld in einer der Vorlagen. 
				|Dann versuchen Sie erneut.'");
			ErrorMessage = StrTemplate(ErrorTemplate, Selection.ErrorField, Selection.RefPresentation, Selection.Code);
			
			For Each EntriesTemplateRow In EntriesTemplatesMap[Selection.Ref] Do
				
				DriveServer.ShowMessageAboutError(
					ThisObject,
					ErrorMessage,
					ActiveTSName,
					EntriesTemplateRow.LineNumber,
					"LineNumber",
					Cancel);
					
			EndDo;
			
		EndDo;
	EndDo;
	
EndProcedure

Procedure CheckTemplatesActiveStatus(Cancel, EntriesTemplatesRefs, EntriesTemplatesMap, ActiveTSName)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	AccountingEntriesTemplates.Presentation AS RefPresentation,
	|	AccountingEntriesTemplates.Code AS Code,
	|	AccountingEntriesTemplates.Ref AS Ref
	|FROM
	|	Catalog.AccountingEntriesTemplates AS AccountingEntriesTemplates
	|WHERE
	|	AccountingEntriesTemplates.Ref IN(&EntriesTemplatesRefs)
	|	AND AccountingEntriesTemplates.Status <> VALUE(Enum.AccountingEntriesTemplatesStatuses.Active)";
	
	Query.SetParameter("EntriesTemplatesRefs", GetEntriesRefs());
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		
		ErrorTemplate = NStr("en = 'Cannot save the template. 
			|It includes an inactive entry template %2 (%3). 
			|Set the entry template status to ""Active"". 
			|Then try again.'; 
			|ru = 'Не удалось сохранить шаблон. Он включает в себя неактивный шаблон проводок %2 (%3). 
			|Установите для шаблона проводок статус ""Активен"" и повторите попытку.';
			|pl = 'Nie można zapisać szablonu. 
			|Obejmuje on nieaktywny szablon wpisu %2 (%3). 
			|Ustaw status szablonu wpisu na ""Aktywny"". 
			|Zatem spróbuj ponownie.';
			|es_ES = 'No se puede guardar la plantilla. 
			|Incluye una plantilla de entrada de diario inactiva %2 (%3). 
			|Establece el estado de la plantilla de entrada en ""Activo"". 
			|Inténtelo de nuevo.';
			|es_CO = 'No se puede guardar la plantilla. 
			|Incluye una plantilla de entrada de diario inactiva %2 (%3). 
			|Establece el estado de la plantilla de entrada en ""Activo"". 
			|Inténtelo de nuevo.';
			|tr = 'Şablon kaydedilemiyor. 
			|Şablon, aktif olmayan bir giriş şablonu %2 (%3) içeriyor. 
			|Giriş şablonu durumunu ""Aktif"" olarak ayarlayın.
			|Ardından, tekrar deneyin.';
			|it = 'Impossibile salvare il modello.
			|Contiene un modello di voce inattivo %2 (%3).
			|Impostare lo stato del modello della voce su ""Attivo"",
			| poi riprovare.';
			|de = 'Fehler beim Speichern der Vorlage. 
			|Sie enthält eine inaktive Buchungsvorlage %2 (%3). 
			|Legen Sie den Status der Buchungsvorlage als ""Aktiv"" fest. 
			|Dann versuchen Sie erneut.'");
		ErrorMessage = StrTemplate(ErrorTemplate, Selection.RefPresentation, Selection.Code);
		
		TransactionTemplateRows = EntriesTemplatesMap[Selection.Ref];
		
		If TransactionTemplateRows <> Undefined And TransactionTemplateRows.Count() > 0 Then
			LineNumber = TransactionTemplateRows[0].LineNumber;
		Else
			Continue;
		EndIf;
		
		DriveServer.ShowMessageAboutError(
			ThisObject,
			ErrorMessage,
			ActiveTSName,
			LineNumber,
			"LineNumber",
			Cancel);
			
	EndDo;
	
EndProcedure

Procedure CheckStatusBeforeDeletionMark(Cancel)
	
	If DeletionMark And Status = Enums.AccountingEntriesTemplatesStatuses.Active Then
		
		MessageText = NStr("en = 'Cannot mark for deletion the accounting transaction template with the Active status.'; ru = 'Не удалось пометить на удаление шаблон бухгалтерских операций, поскольку его статус – ""Активен"".';pl = 'Nie można zaznaczyć do usunięcia szablonu transakcji księgowej o statusie Aktywny.';es_ES = 'No se puede marcar para su eliminación el modelo de transacción contable con el estado Activo.';es_CO = 'No se puede marcar para su eliminación el modelo de transacción contable con el estado Activo.';tr = 'Aktif durumdaki muhasebe işlemi şablonu silinmek üzere işaretlenemez.';it = 'Impossibile contrassegnare per l''eliminazione il modello di transazione di contabilità con stato Attivo.';de = 'Fehler beim Markieren zum Löschen der Buchhaltungstransaktionsvorlagen mit dem Status Aktiv.'");
		DriveServer.ShowMessageAboutError(ThisObject, MessageText, , , , Cancel);
		
	EndIf;
	
EndProcedure

Function GetEntriesRefs()

	If Entries.Count() > 0 Then
		Return Entries.UnloadColumn("EntriesTemplate");
	ElsIf EntriesSimple.Count() > 0 Then
		Return EntriesSimple.UnloadColumn("EntriesTemplate");
	Else
		Return New Array;
	EndIf;

EndFunction 

Function GetEntriesRefsMap()

	RefsMap = New Map;
	
	If Entries.Count() > 0 Then
		EntriesTabSection = Entries;
	ElsIf EntriesSimple.Count() > 0 Then
		EntriesTabSection = EntriesSimple;
	Else
		Return RefsMap;
	EndIf;
	
	EntriesTemplates = EntriesTabSection.Unload(, "EntriesTemplate");
	EntriesTemplates.GroupBy("EntriesTemplate");
	For Each Row In EntriesTemplates Do
		
		Filter = New Structure;
		Filter.Insert("EntriesTemplate", Row.EntriesTemplate);
		
		FoundRows = EntriesTabSection.FindRows(Filter);
		
		RefsMap.Insert(Row.EntriesTemplate, FoundRows);
		
	EndDo;
	
	Return RefsMap;
	
EndFunction 

Procedure CheckTemplatesPeriods(Cancel) Export
	 
	EntriesTemplatesMap	= GetEntriesRefsMap();
	ActiveTSName		= ?(Entries.Count() > 0, "Entries", "EntriesSimple");
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	AccountingEntriesTemplates.StartDate AS EntriesStartDate,
	|	AccountingEntriesTemplates.EndDate AS EntriesEndDate,
	|	AccountingEntriesTemplates.Ref AS Ref,
	|	AccountingEntriesTemplates.Code AS Code
	|FROM
	|	Catalog.AccountingEntriesTemplates AS AccountingEntriesTemplates
	|WHERE
	|	AccountingEntriesTemplates.Ref IN(&EntriesTemplatesRefs)
	|	AND (AccountingEntriesTemplates.StartDate > &StartDate
	|			OR CASE
	|				WHEN &EndDate = DATETIME(1, 1, 1)
	|						AND AccountingEntriesTemplates.EndDate <> DATETIME(1, 1, 1)
	|					THEN TRUE
	|				WHEN AccountingEntriesTemplates.EndDate = DATETIME(1, 1, 1)
	|						AND &EndDate <> DATETIME(1, 1, 1)
	|					THEN FALSE
	|				ELSE AccountingEntriesTemplates.EndDate < &EndDate
	|			END)";
	
	Query.SetParameter("EntriesTemplatesRefs", GetEntriesRefs());
	
	If Status = Enums.AccountingEntriesTemplatesStatuses.Active Then
		Query.SetParameter("StartDate", StartDate);
		Query.SetParameter("EndDate"  , EndDate);
	Else
		Query.SetParameter("StartDate", PlanStartDate);
		Query.SetParameter("EndDate"  , PlanEndDate);
	EndIf;
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		
		ErrorTemplate = NStr("en = 'Line %1 contains entries template ""%2"" with validity period ""%3"" that does not match the validity period of this template. Select a different entries template or adjust the validity period of this template.'; ru = 'Строка %1 содержит шаблон проводок ""%2"" со сроком действия ""%3"", который не соответствует сроку действия этого шаблона. Выберите другой шаблон проводок или измените срок действия этого шаблона.';pl = 'Wiersz %1 obejmuje szablon wpisów ""%2"" z okresem ważności ""%3"", który nie jest zgodny z okresem ważności tego szablonu. Wybierz inny szablon wpisów lub dostosuj okres ważności tego szablonu.';es_ES = 'La línea %1 contiene la plantilla de entradas de diario ""%2""con periodo de validez ""%3"" que no coincide con el periodo de validez de esta plantilla. Selecciona una plantilla de entradas de diario diferente o ajusta el periodo de validez de esta plantilla.';es_CO = 'La línea %1 contiene la plantilla de entradas de diario ""%2""con periodo de validez ""%3"" que no coincide con el periodo de validez de esta plantilla. Selecciona una plantilla de entradas de diario diferente o ajusta el periodo de validez de esta plantilla.';tr = '%1 satırının içerdiği ""%2"" giriş şablonunun ""%3"" geçerlilik dönemi, bu şablonun geçerlilik dönemiyle eşleşmiyor. Başka bir giriş şablonu seçin veya bu şablonun geçerlilik dönemini düzeltin.';it = 'La riga %1 contiene un modello di voce ""%2"" con periodo di validità ""%3"" che non corrisponde al periodo di validità di questo modello. Selezionare un modello di voce differente o modificare il periodo di validità di questo modello.';de = 'Zeile %1 enthält Buchungsvorlage ""%2"" mit Gültigkeitsdauer ""%3"" die mit der Gültigkeitsdauer dieser Vorlage nicht übereinstimmt. Wählen Sie eine andere Buchungsvorlage aus oder ändern Sie die Gültigkeitsdauer dieser Vorlage.'");
		
		ValidityPeriodText	= StrTemplate(Nstr("en = '%1 - %2'; ru = '%1 - %2';pl = '%1 - %2';es_ES = '%1 - %2';es_CO = '%1 - %2';tr = '%1 - %2';it = '%1 - %2';de = '%1 - %2'"),
			Format(Selection.EntriesStartDate	, "DLF=D; DE=..."),
			Format(Selection.EntriesEndDate		, "DLF=D; DE=..."));
		
		For Each Row In EntriesTemplatesMap[Selection.Ref] Do
			
			ErrorMessage = StrTemplate(ErrorTemplate, Row.LineNumber, Selection.Code, ValidityPeriodText);
			
			DriveServer.ShowMessageAboutError(
				ThisObject,
				ErrorMessage,
				ActiveTSName,
				Row.LineNumber,
				"LineNumber",
				Cancel);
			
		EndDo;
	EndDo;
	
EndProcedure

#EndRegion

#EndIf