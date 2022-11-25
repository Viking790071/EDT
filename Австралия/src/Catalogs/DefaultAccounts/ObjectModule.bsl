#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	FilterPresentation = "";
	
	For Each Row In Filters Do
		If ValueIsFilled(Row.Value) Then
			FilterPresentation = FilterPresentation + StrTemplate("%1; ", Row.Value);
		EndIf;
	EndDo;
	
	FilterPresentation = TrimAll(FilterPresentation);
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	CheckDates(Cancel);
	CheckCompanyDates(Cancel);
	CheckUnique(Cancel);
	
	If Not Cancel Then
		
		RecordSetDefaultAccounts = InformationRegisters.DefaultAccounts.CreateRecordSet();
		
		RecordSetDefaultAccounts.Filter.DefaultAccount.Set(Ref);
		
		RowStructure = New Structure;
		
		RowStructure.Insert("DefaultAccountType", DefaultAccountType);
		RowStructure.Insert("DefaultAccount"	, Ref);
		
		For Each Row In Filters Do
			If ValueIsFilled(Row.Value) Then
				AttrName = StrTemplate("Filter%1", Format(Row.LineNumber, "NFD=0; NS=; NG="));
				RowStructure.Insert(AttrName, Row.Value);
			EndIf;
		EndDo;
		
		For Each Row In Accounts Do
			
			RowStructure.Insert("AccountReferenceName", Row.AccountReferenceName);
			RowStructure.Insert("Account", Row.Account);
			
			NewRow = RecordSetDefaultAccounts.Add();
			
			FillPropertyValues(NewRow, RowStructure);
			
		EndDo;
		
		RecordSetDefaultAccounts.Write();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Procedure CheckCompanyDates(Cancel)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	DefaultAccountsAccounts.LineNumber AS LineNumber,
	|	DefaultAccountsAccounts.Account AS Account,
	|	CASE
	|		WHEN &StartDate = DATETIME(1, 1, 1)
	|			THEN DATETIME(1, 1, 1)
	|		ELSE MasterChartOfAccounts.StartDate
	|	END AS DefaultStartDate,
	|	CASE
	|		WHEN &EndDate = DATETIME(3999, 12, 31)
	|				OR MasterChartOfAccounts.EndDate = DATETIME(1, 1, 1)
	|			THEN DATETIME(3999, 12, 31)
	|		ELSE MasterChartOfAccounts.EndDate
	|	END AS DefaultEndDate
	|INTO Accounts
	|FROM
	|	Catalog.DefaultAccounts.Accounts AS DefaultAccountsAccounts
	|		LEFT JOIN ChartOfAccounts.MasterChartOfAccounts AS MasterChartOfAccounts
	|		ON DefaultAccountsAccounts.Account = MasterChartOfAccounts.Ref
	|WHERE
	|	DefaultAccountsAccounts.Ref = &Ref
	|	AND DefaultAccountsAccounts.Account REFS ChartOfAccounts.MasterChartOfAccounts
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MasterChartOfAccountsCompanies.Ref AS Ref
	|INTO AccountsWithCompanies
	|FROM
	|	ChartOfAccounts.MasterChartOfAccounts.Companies AS MasterChartOfAccountsCompanies
	|WHERE
	|	MasterChartOfAccountsCompanies.Ref IN
	|			(SELECT
	|				Accounts.Account AS Account
	|			FROM
	|				Accounts AS Accounts)
	|	AND &CompanyIsFilled
	|
	|GROUP BY
	|	MasterChartOfAccountsCompanies.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MasterChartOfAccountsCompanies.Ref AS Ref,
	|	CASE
	|		WHEN &StartDate = DATETIME(1, 1, 1)
	|			THEN DATETIME(1, 1, 1)
	|		ELSE MasterChartOfAccountsCompanies.StartDate
	|	END AS StartDate,
	|	CASE
	|		WHEN &EndDate = DATETIME(3999, 12, 31)
	|				OR MasterChartOfAccountsCompanies.EndDate = DATETIME(1, 1, 1)
	|			THEN DATETIME(3999, 12, 31)
	|		ELSE MasterChartOfAccountsCompanies.EndDate
	|	END AS EndDate
	|INTO PeriodForCompany
	|FROM
	|	ChartOfAccounts.MasterChartOfAccounts.Companies AS MasterChartOfAccountsCompanies
	|WHERE
	|	MasterChartOfAccountsCompanies.Ref IN
	|			(SELECT
	|				AccountsWithCompanies.Ref AS Ref
	|			FROM
	|				AccountsWithCompanies AS AccountsWithCompanies)
	|	AND MasterChartOfAccountsCompanies.Company = &Company
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsWithCompanies.Ref AS Ref,
	|	CASE
	|		WHEN PeriodForCompany.Ref IS NULL
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ErrorCompany,
	|	CASE
	|		WHEN NOT PeriodForCompany.Ref IS NULL
	|			THEN CASE
	|					WHEN &StartDate BETWEEN PeriodForCompany.StartDate AND PeriodForCompany.EndDate
	|							AND (&EndDate BETWEEN PeriodForCompany.StartDate AND PeriodForCompany.EndDate)
	|						THEN TRUE
	|					ELSE FALSE
	|				END
	|		ELSE FALSE
	|	END AS PeriodIsCondition
	|INTO PeriodCompanyCondition
	|FROM
	|	AccountsWithCompanies AS AccountsWithCompanies
	|		LEFT JOIN PeriodForCompany AS PeriodForCompany
	|		ON AccountsWithCompanies.Ref = PeriodForCompany.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Accounts.LineNumber AS LineNumber,
	|	Accounts.Account AS Account,
	|	ISNULL(PeriodCompanyCondition.ErrorCompany, FALSE) AS ErrorCompany,
	|	CASE
	|		WHEN PeriodCompanyCondition.Ref IS NULL
	|			THEN CASE
	|					WHEN &StartDate BETWEEN Accounts.DefaultStartDate AND Accounts.DefaultEndDate
	|							AND (&EndDate BETWEEN Accounts.DefaultStartDate AND Accounts.DefaultEndDate)
	|						THEN TRUE
	|					ELSE FALSE
	|				END
	|		ELSE PeriodCompanyCondition.PeriodIsCondition
	|	END AS PeriodIsCondition
	|INTO ResultErrors
	|FROM
	|	Accounts AS Accounts
	|		LEFT JOIN PeriodCompanyCondition AS PeriodCompanyCondition
	|		ON Accounts.Account = PeriodCompanyCondition.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ResultErrors.LineNumber AS LineNumber,
	|	ResultErrors.Account AS Account,
	|	ResultErrors.ErrorCompany AS ErrorCompany,
	|	ResultErrors.PeriodIsCondition AS PeriodIsCondition
	|FROM
	|	ResultErrors AS ResultErrors
	|WHERE
	|	(ResultErrors.ErrorCompany
	|			OR NOT ResultErrors.PeriodIsCondition)";
	
	Query.SetParameter("Company"		, Company);
	Query.SetParameter("EndDate"		, ?(ValueIsFilled(EndDate), EndDate, Date(3999, 12, 31)));
	Query.SetParameter("Ref"			, Ref);
	Query.SetParameter("StartDate"		, StartDate);
	Query.SetParameter("CompanyIsFilled", ValueIsFilled(Company));
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		If ValueIsFilled(Company) Then
			
			ErrorTemplate = NStr("en = 'In line # %2, for %3, the validity period of ""%1"" must be within the validity period of the default account. Adjust the account validity period. Then try again.'; ru = 'В строке № %2 для %3 срок действия ""%1"" должен быть в пределах срока действия счета по умолчанию. Измените срок действия счета и повторите попытку.';pl = 'W wierszu nr %2, dla %3, okres ważności ""%1"" musi mieścić się w okresie ważności konta domyślnego. Zmień okres ważności konta  Następnie spróbuj ponownie.';es_ES = 'En la línea #%2, para%3, el periodo de validez de ""%1"" debe estar dentro del periodo de validez de la cuenta por defecto. Ajuste el periodo de validez de la cuenta. Inténtelo de nuevo.';es_CO = 'En la línea #%2, para%3, el periodo de validez de ""%1"" debe estar dentro del periodo de validez de la cuenta por defecto. Ajuste el periodo de validez de la cuenta. Inténtelo de nuevo.';tr = '%2 numaralı satırda %3 için ""%1"" geçerlilik süresi, varsayılan hesabın geçerlilik süresi içinde olmalıdır. Hesabın geçerlilik süresini düzeltip tekrar deneyin.';it = 'Nella riga #%2, per %3, il periodo di validità di ""%1"" deve essere incluso nel periodo di validità del conto predefinito. Correggere il periodo di validità del conto, poi riprovare.';de = 'In der Zeile %2, muss die Gültigkeitsdauer von ""%1"" für %3, innerhalb der Gültigkeitsdauer des Standardkontos liegen. Passen Sie die Gültigkeitsdauer des Kontos an. Dann versuchen Sie erneut.'");
			ErrorMessage = StrTemplate(ErrorTemplate, SelectionDetailRecords.Account, SelectionDetailRecords.LineNumber, Company);
			DriveServer.ShowMessageAboutError(ThisObject, ErrorMessage, "Accounts", SelectionDetailRecords.LineNumber, "Account", Cancel);
			
		Else
			
			ErrorTemplate = NStr("en = 'In line # %2, the validity period of ""%1"" must be within the validity period of the default account. Adjust the account validity period. Then try again.'; ru = 'В строке № %2 срок действия ""%1"" должен быть в пределах срока действия счета по умолчанию. Измените срок действия счета и повторите попытку.';pl = 'W wierszu nr %2, okres ważności ""%1"" musi mieścić się w okresie ważności konta domyślnego. Zmień okres ważności konta  Następnie spróbuj ponownie.';es_ES = 'En la línea #%2, el periodo de validez de ""%1"" debe estar dentro del periodo de validez de la cuenta por defecto. Ajuste el periodo de validez de la cuenta. Inténtelo de nuevo.';es_CO = 'En la línea #%2, el periodo de validez de ""%1"" debe estar dentro del periodo de validez de la cuenta por defecto. Ajuste el periodo de validez de la cuenta. Inténtelo de nuevo.';tr = '%2 numaralı satırda ""%1"" geçerlilik süresi, varsayılan hesabın geçerlilik süresi içinde olmalıdır. Hesabın geçerlilik süresini düzeltip tekrar deneyin.';it = 'Nella riga #%2, il periodo di validità di ""%1"" deve essere incluso nel periodo di validità del conto predefinito. Correggere il periodo di validità del conto, poi riprovare.';de = 'In der Zeile %2, muss die Gültigkeitsdauer von ""%1"" für innerhalb der Gültigkeitsdauer des Standardkontos liegen. Passen Sie die Gültigkeitsdauer des Kontos an. Dann versuchen Sie erneut.'");
			ErrorMessage = StrTemplate(ErrorTemplate, SelectionDetailRecords.Account, SelectionDetailRecords.LineNumber);
			DriveServer.ShowMessageAboutError(ThisObject, ErrorMessage, "Accounts", SelectionDetailRecords.LineNumber, "Account", Cancel);
			
		EndIf;
		
	EndDo;
		
EndProcedure

Procedure CheckDates(Cancel)
	
	If ValueIsFilled(EndDate) And StartDate > EndDate Then
		
		ErrorMessage = NStr("en = 'For the default account, the ""Active from"" date must be equal to or earlier than the ""to"" date. Edit the ""to"" date. Then try again.'; ru = 'Для счета по умолчанию дата в поле ""Активен с"" не должна превышать дату в поле ""по"". Измените дату в поле ""по"" и повторите попытку.';pl = 'Dla domyślnego konta, data ""Ważne od"" musi być równa lub wcześniejsza niż data ""do"". Edytuj datę ""do"". Zatem spróbuj ponownie.';es_ES = 'Para la cuenta por defecto, la fecha ""Activo desde"" debe ser igual o anterior a la fecha ""hasta"". Edite la fecha ""hasta"". Inténtelo de nuevo.';es_CO = 'Para la cuenta por defecto, la fecha ""Activo desde"" debe ser igual o anterior a la fecha ""hasta"". Edite la fecha ""hasta"". Inténtelo de nuevo.';tr = 'Varsayılan hesap için, ""Aktivasyon başlangıcı"" tarihi ""bitiş"" tarihiyle aynı veya daha önce olmalıdır. ""bitiş"" tarihini düzenleyip tekrar deneyin.';it = 'Per il conto predefinito, la data ""Attivo da"" deve essere uguale o precedente alla data ""fino a"". Modificare la data ""fino a"", poi riprovare.';de = 'Für das Standardkonto muss das Datum ""Aktiv vom"" gleich oder vor dem Datum ""bis"" liegen. Bearbeiten Sie das Datum ""bis"". Dann versuchen Sie erneut.'");
		DriveServer.ShowMessageAboutError(ThisObject, ErrorMessage, , , "EndDate", Cancel);
		
	EndIf;
		
EndProcedure

Procedure CheckUnique(Cancel)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	DefaultAccounts.Ref AS Ref,
	|	DefaultAccounts.StartDate AS StartDate,
	|	CASE
	|		WHEN DefaultAccounts.EndDate = DATETIME(1, 1, 1)
	|			THEN DATETIME(3999, 12, 31)
	|		ELSE DefaultAccounts.EndDate
	|	END AS EndDate
	|INTO RefsTableWithDates
	|FROM
	|	Catalog.DefaultAccounts AS DefaultAccounts
	|WHERE
	|	DefaultAccounts.Company = &Company
	|	AND DefaultAccounts.TypeOfAccounting = &TypeOfAccounting
	|	AND DefaultAccounts.ChartOfAccounts = &ChartOfAccounts
	|	AND DefaultAccounts.DefaultAccountType = &DefaultAccountType
	|	AND DefaultAccounts.Ref <> &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RefsTableWithDates.Ref AS Ref
	|INTO RefsTable
	|FROM
	|	RefsTableWithDates AS RefsTableWithDates
	|WHERE
	|	RefsTableWithDates.StartDate >= &StartDate
	|	AND RefsTableWithDates.StartDate <= &EndDate
	|
	|UNION ALL
	|
	|SELECT
	|	RefsTableWithDates.Ref
	|FROM
	|	RefsTableWithDates AS RefsTableWithDates
	|WHERE
	|	RefsTableWithDates.EndDate >= &StartDate
	|	AND RefsTableWithDates.EndDate <= &EndDate
	|
	|UNION ALL
	|
	|SELECT
	|	RefsTableWithDates.Ref
	|FROM
	|	RefsTableWithDates AS RefsTableWithDates
	|WHERE
	|	RefsTableWithDates.StartDate < &StartDate
	|	AND RefsTableWithDates.EndDate > &EndDate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RefsTable.Ref AS Ref
	|INTO RefsWithFilters
	|FROM
	|	RefsTable AS RefsTable
	|		INNER JOIN Catalog.DefaultAccounts.Filters AS DefaultAccountsFilters
	|		ON RefsTable.Ref = DefaultAccountsFilters.Ref
	|WHERE
	|	DefaultAccountsFilters.Value IN(&Value)
	|
	|GROUP BY
	|	RefsTable.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RefsWithFilters.Ref AS Ref,
	|	COUNT(DISTINCT DefaultAccountsFilters.Value) AS CountFilter,
	|	SUM(CASE
	|			WHEN DefaultAccountsFilters.Value IN (&Value)
	|				THEN 1
	|			ELSE 0
	|		END) AS CountFilterCurrentRef
	|INTO Filter
	|FROM
	|	RefsWithFilters AS RefsWithFilters
	|		INNER JOIN Catalog.DefaultAccounts.Filters AS DefaultAccountsFilters
	|		ON RefsWithFilters.Ref = DefaultAccountsFilters.Ref
	|
	|GROUP BY
	|	RefsWithFilters.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Filter.Ref AS Ref
	|INTO NotUniqueFilter
	|FROM
	|	Filter AS Filter
	|WHERE
	|	Filter.CountFilter = Filter.CountFilterCurrentRef
	|	AND Filter.CountFilterCurrentRef = &CountFilter
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	RefsWithFilters.Ref AS Ref
	|FROM
	|	RefsWithFilters AS RefsWithFilters
	|		INNER JOIN NotUniqueFilter AS NotUniqueFilter
	|		ON RefsWithFilters.Ref = NotUniqueFilter.Ref";
	
	Query.SetParameter("ChartOfAccounts"	, ChartOfAccounts);
	Query.SetParameter("DefaultAccountType"	, DefaultAccountType);
	Query.SetParameter("Company"			, Company);
	Query.SetParameter("CountFilter"		, Filters.Count());
	Query.SetParameter("Value"				, Filters.UnloadColumn("Value"));
	Query.SetParameter("Ref"				, Ref);
	Query.SetParameter("TypeOfAccounting"	, TypeOfAccounting);
	Query.SetParameter("StartDate"			, StartDate);
	Query.SetParameter("EndDate"			, ?(ValueIsFilled(EndDate), EndDate, Date(3999, 12, 31)));
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	ErrorMessage = "";
	
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		ErrorMessage = ErrorMessage + ?(ValueIsFilled(ErrorMessage), Chars.LF, "") + Selection.Ref;
	EndDo;
	
	ErrorMessage = NStr("en = 'Cannot save the settings. The default account with the same settings already exists. Adjust the validity period of the existing default account. Then, if required, create another default account with a different validity period.'; ru = 'Не удалось сохранить настройки. Счет по умолчанию с такими же настройками уже существует. Измените срок действия существующего счета по умолчанию и, если потребуется, создайте еще один счет по умолчанию с другим сроком действия.';pl = 'Nie można zapisać zmian. Domyślne konto z tymi samymi ustawieniami już istnieje. Zmież okres ważności istniejącego konta domyślnego. Zatem, w razie konieczności, utwórz inne domyślne konto z innym okresem ważności.';es_ES = 'No se puede guardar las configuraciones. La cuenta por defecto con los mismos ajustes ya existe. Ajuste el periodo de validez de la cuenta existente por defecto. A continuación, si es necesario, cree otra cuenta por defecto con un periodo de validez diferente.';es_CO = 'No se puede guardar las configuraciones. La cuenta por defecto con los mismos ajustes ya existe. Ajuste el periodo de validez de la cuenta existente por defecto. A continuación, si es necesario, cree otra cuenta por defecto con un periodo de validez diferente.';tr = 'Ayarlar kaydedilemiyor. Aynı ayarlara sahip varsayılan hesap zaten mevcut. Mevcut varsayılan hesabın geçerlilik süresini düzeltin. Ardından, gerekiyorsa farklı geçerlilik süresine sahip başka bir hesap oluşturun.';it = 'Impossibile salvare le impostazioni. Un conto predefinito con le stesse impostazioni esiste già. Correggere il periodo di validità del conto predefinito esistente. Poi, se richiesto, creare un altro conto predefinito con un periodo di validità differente.';de = 'Fehler beim Speichern von Änderungen. Das Standardkonto mit denselben Einstellungen besteht bereits. Ändern Sie die Gültigkeitsdauer des bestehenden Standardkontos. Dann ggf. erstellen Sie ein neues Standardkonto mit einer anderen Gültigkeitsdauer.'") + Chars.LF + ErrorMessage;
	DriveServer.ShowMessageAboutError(ThisObject, ErrorMessage, , , , Cancel);
	
EndProcedure

#EndRegion

#EndIf