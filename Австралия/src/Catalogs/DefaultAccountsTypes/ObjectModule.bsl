
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	CheckDescriptionIsUnique(Cancel);
	CheckUnique(Cancel);
	CheckFiltersIsUnique(Cancel);
	CheckAccountsIsUnique(Cancel);
	CheckCountFilters(Cancel);
	CheckUsedInDefaultAccounts(Cancel);
	
EndProcedure

#EndRegion

#Region Private

Procedure CheckDescriptionIsUnique(Cancel)

	Query = New Query;
	Query.Text = 
	"SELECT
	|	DefaultAccountsTypes.Ref AS Ref
	|FROM
	|	Catalog.DefaultAccountsTypes AS DefaultAccountsTypes
	|WHERE
	|	DefaultAccountsTypes.Description = &Description
	|	AND DefaultAccountsTypes.Ref <> &Ref
	|	AND DefaultAccountsTypes.Company = &Company
	|	AND DefaultAccountsTypes.TypeOfAccounting = &TypeOfAccounting
	|	AND DefaultAccountsTypes.ChartOfAccounts = &ChartOfAccounts";
	
	Query.SetParameter("Description"		, Description);
	Query.SetParameter("Company"			, Company);
	Query.SetParameter("TypeOfAccounting"	, TypeOfAccounting);
	Query.SetParameter("ChartOfAccounts"	, ChartOfAccounts);
	Query.SetParameter("Ref"				, Ref);
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		ErrorTemplate = NStr("en = 'The value ""%1"" of the field ""Description"" is not unique.'; ru = 'Значение ""%1"" поля ""Наименование"" уже существует.';pl = 'Wartość ""%1"" pola ""Opis"" nie jest unikalna.';es_ES = 'El valor ""%1"" del campo ""Descripción"" no es único.';es_CO = 'El valor ""%1"" del campo ""Descripción"" no es único.';tr = '""Tanım"" alanının ""%1"" değeri benzersiz değil.';it = 'Il valore ""%1"" del campo ""Descrizione"" non è univoco.';de = 'Der Wert ""%1"" des Felds ""Beschreibung"" ist nicht einzigartig.'");
		ErrorMessage = StrTemplate(ErrorTemplate, Description);
		DriveServer.ShowMessageAboutError(ThisObject, ErrorMessage, , , "Description", Cancel);
		
	EndIf;
	
EndProcedure

Procedure CheckFiltersIsUnique(Cancel)
	
	ArrayFilterName = New Array;
	
	For Each Row In Filters Do
		
		If ArrayFilterName.Find(Row.FilterName) <> Undefined Then
			Continue;
		EndIf;
		
		ArrayFilterName.Add(Row.FilterName);
		
		FindRows = Filters.FindRows(New Structure("FilterName", Row.FilterName));
		
		If FindRows.Count() > 1 Then
			
			ErrorMessage = NStr("en = 'Cannot save the default account type. The Filter settings include duplicate lines. Remove the duplicates. Then try again.'; ru = 'Не удалось сохранить тип счета по умолчанию. Настройки отбора включают повторяющиеся строки. Удалите дубликаты и повторите попытку.';pl = 'Nie można zapisać domyślnego typu konta. Ustawienia filtru zawierają powtarzające się wiersze. Usuń duplikaty. Zatem spróbuj ponownie.';es_ES = 'No se puede guardar el tipo de cuenta por defecto. La configuración del filtro incluye líneas duplicadas. Elimine los duplicados. Inténtelo de nuevo.';es_CO = 'No se puede guardar el tipo de cuenta por defecto. La configuración del filtro incluye líneas duplicadas. Elimine los duplicados. Inténtelo de nuevo.';tr = 'Varsayılan hesap türü kaydedilemiyor. Filtre ayarları tekrarlayan satırlar içeriyor. Tekrarları çıkarıp yeniden deneyin.';it = 'Impossibile salvare il tipo di conto predefinito. Le impostazioni di filtro includono righe duplicate. Rimuovere i duplicati, poi riprovare.';de = 'Fehler beim Speichern von des Standardkontotyps. Die Filtereinstellungen enthalten verdoppelte Zeilen. Entfernen Sie die Duplikate. Dann versuchen Sie erneut.'");
			DriveServer.ShowMessageAboutError(ThisObject, ErrorMessage, "Filters", Row.LineNumber, "FilterSynonym", Cancel);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure CheckAccountsIsUnique(Cancel)
	
	ArrayAccountReferenceName = New Array;
	
	For Each Row In Accounts Do
		
		If ArrayAccountReferenceName.Find(Row.AccountReferenceName) <> Undefined Then
			Continue;
		EndIf;
		
		ArrayAccountReferenceName.Add(Row.AccountReferenceName);
		
		FindRows = Accounts.FindRows(New Structure("AccountReferenceName", Row.AccountReferenceName));
		
		If FindRows.Count() > 1 Then
			
			ErrorMessage = NStr("en = 'Cannot save the default account type. The Account settings include duplicate Account reference names. Remove the duplicates. Then try again.'; ru = 'Не удалось сохранить тип счета по умолчанию. Настройки счета включают повторяющиеся ссылочные имена счетов. Удалите дубликаты и повторите попытку.';pl = 'Nie można zapisać domyślnego typu konta. Ustawienia Konta zawierają powtarzające się nazwy referencyjne Konta. Usuń duplikaty. Zatem spróbuj ponownie.';es_ES = 'No se puede guardar el tipo de cuenta por defecto. La configuración de la cuenta incluye nombres de referencia de la cuenta duplicados. Elimine los duplicados. Inténtelo de nuevo.';es_CO = 'No se puede guardar el tipo de cuenta por defecto. La configuración de la cuenta incluye nombres de referencia de la cuenta duplicados. Elimine los duplicados. Inténtelo de nuevo.';tr = 'Varsayılan hesap türü kaydedilemiyor. Hesap ayarları tekrarlayan Hesap referans adları içeriyor. Tekrarları çıkarıp yeniden deneyin.';it = 'Impossibile salvare il tipo di conto predefinito. Le impostazioni di Conto includono nomi di riferimento di conto duplicati. Rimuovere i duplicati, poi riprovare.';de = 'Fehler beim Speichern von des Standardkontotyps. Die Kontoeinstellungen enthalten verdoppelte Kontoreferenznamen. Entfernen Sie die Duplikate. Dann versuchen Sie erneut.'");
			DriveServer.ShowMessageAboutError(ThisObject, ErrorMessage, "Accounts", Row.LineNumber, "AccountReferenceName", Cancel);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure CheckUnique(Cancel)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	DefaultAccountsTypes.Ref AS Ref
	|INTO RefsTable
	|FROM
	|	Catalog.DefaultAccountsTypes AS DefaultAccountsTypes
	|WHERE
	|	DefaultAccountsTypes.Company = &Company
	|	AND DefaultAccountsTypes.TypeOfAccounting = &TypeOfAccounting
	|	AND DefaultAccountsTypes.ChartOfAccounts = &ChartOfAccounts
	|	AND DefaultAccountsTypes.Ref <> &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RefsTable.Ref AS Ref
	|INTO RefsWithFiltersAndAccounts
	|FROM
	|	RefsTable AS RefsTable
	|		INNER JOIN Catalog.DefaultAccountsTypes.Filters AS DefaultAccountsTypesFilters
	|		ON RefsTable.Ref = DefaultAccountsTypesFilters.Ref
	|		INNER JOIN Catalog.DefaultAccountsTypes.Accounts AS DefaultAccountsTypesAccounts
	|		ON RefsTable.Ref = DefaultAccountsTypesAccounts.Ref
	|WHERE
	|	DefaultAccountsTypesFilters.FilterName IN(&FilterName)
	|	AND DefaultAccountsTypesAccounts.AccountReferenceName IN(&Account)
	|
	|GROUP BY
	|	RefsTable.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RefsWithFiltersAndAccounts.Ref AS Ref,
	|	COUNT(DISTINCT DefaultAccountsTypesFilters.FilterName) AS CountFilter,
	|	SUM(CASE
	|			WHEN DefaultAccountsTypesFilters.FilterName IN (&FilterName)
	|				THEN 1
	|			ELSE 0
	|		END) AS CountFilterCurrentRef
	|INTO Filter
	|FROM
	|	RefsWithFiltersAndAccounts AS RefsWithFiltersAndAccounts
	|		INNER JOIN Catalog.DefaultAccountsTypes.Filters AS DefaultAccountsTypesFilters
	|		ON RefsWithFiltersAndAccounts.Ref = DefaultAccountsTypesFilters.Ref
	|
	|GROUP BY
	|	RefsWithFiltersAndAccounts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RefsWithFiltersAndAccounts.Ref AS Ref,
	|	SUM(CASE
	|			WHEN DefaultAccountsTypesAccounts.AccountReferenceName IN (&Account)
	|				THEN 1
	|			ELSE 0
	|		END) AS CountAccountCurrentRef,
	|	COUNT(DISTINCT DefaultAccountsTypesAccounts.AccountReferenceName) AS CountAccount
	|INTO Accounts
	|FROM
	|	RefsWithFiltersAndAccounts AS RefsWithFiltersAndAccounts
	|		INNER JOIN Catalog.DefaultAccountsTypes.Accounts AS DefaultAccountsTypesAccounts
	|		ON RefsWithFiltersAndAccounts.Ref = DefaultAccountsTypesAccounts.Ref
	|
	|GROUP BY
	|	RefsWithFiltersAndAccounts.Ref
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
	|SELECT
	|	Accounts.Ref AS Ref
	|INTO NotUniqueAccounts
	|FROM
	|	Accounts AS Accounts
	|WHERE
	|	Accounts.CountAccountCurrentRef = Accounts.CountAccount
	|	AND Accounts.CountAccountCurrentRef = &CountAccount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RefsWithFiltersAndAccounts.Ref AS Ref
	|FROM
	|	RefsWithFiltersAndAccounts AS RefsWithFiltersAndAccounts
	|		INNER JOIN NotUniqueFilter AS NotUniqueFilter
	|		ON RefsWithFiltersAndAccounts.Ref = NotUniqueFilter.Ref
	|		INNER JOIN NotUniqueAccounts AS NotUniqueAccounts
	|		ON RefsWithFiltersAndAccounts.Ref = NotUniqueAccounts.Ref";
	
	Query.SetParameter("Account"			, 	Accounts.UnloadColumn("AccountReferenceName"));
	Query.SetParameter("ChartOfAccounts"	, 	ChartOfAccounts);
	Query.SetParameter("Company"			, 	Company);
	Query.SetParameter("CountAccount"		, 	Accounts.Count());
	Query.SetParameter("CountFilter"		, 	Filters.Count());
	Query.SetParameter("FilterName"			, 	Filters.UnloadColumn("FilterName"));
	Query.SetParameter("Ref"				, 	Ref);
	Query.SetParameter("TypeOfAccounting"	, 	TypeOfAccounting);
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	ErrorMessage = "";
	
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		ErrorMessage = ErrorMessage + ?(ValueIsFilled(ErrorMessage), Chars.LF, "") + Selection.Ref;
	EndDo;
	
	ErrorMessage = NStr("en = 'Cannot save the default account type. The default account type with the same settings already exists.'; ru = 'Не удалось сохранить тип счета по умолчанию. Тип счета по умолчанию с такими настройками уже существует.';pl = 'Nie można zapisać domyślnego typu konta. Domyślny typ konta z tymi samymi ustawieniami już istnieją.';es_ES = 'No se puede guardar el tipo de cuenta por defecto. El tipo de cuenta por defecto con la misma configuración ya existe.';es_CO = 'No se puede guardar el tipo de cuenta por defecto. El tipo de cuenta por defecto con la misma configuración ya existe.';tr = 'Varsayılan hesap türü kaydedilemiyor. Aynı ayarlara sahip varsayılan hesap türü zaten mevcut.';it = 'Impossibile salvare il tipo di conto predefinito. Un tipo di conto predefinito con le stesse impostazioni esiste già.';de = 'Fehler beim Speichern von Standardkontotyp. Der Standardkontotyp mit denselben Einstellungen besteht bereits.'")
		+ Chars.LF
		+ ErrorMessage;
	DriveServer.ShowMessageAboutError(ThisObject, ErrorMessage, , , , Cancel);
	
EndProcedure

Procedure CheckCountFilters(Cancel)
	
	If Filters.Count() > 4 Then
		
		ErrorMessage = NStr("en = 'Maximum 4 filters are allowed!'; ru = 'Допускается не более 4 отборов!';pl = 'Dozwolone są maksymalnie 4 filtry!';es_ES = '¡Se permite un máximo de 4 filtros!';es_CO = '¡Se permite un máximo de 4 filtros!';tr = 'En fazla 4 filtreye izin verilir!';it = 'Sono concessi massimo 4 filtri!';de = 'Maximum 4 Filter sind gestattet!'");
		DriveServer.ShowMessageAboutError(ThisObject, ErrorMessage, , , , Cancel);
		
	EndIf;
	
EndProcedure

Procedure CheckUsedInDefaultAccounts(Cancel)
	
	If IsNew() Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	DefaultAccounts.Ref AS Ref
	|FROM
	|	Catalog.DefaultAccounts AS DefaultAccounts
	|WHERE
	|	DefaultAccounts.DefaultAccountType = &DefaultAccountType
	|	AND NOT DefaultAccounts.DeletionMark";
	
	Query.SetParameter("DefaultAccountType", Ref);
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		ModifiedAttributes = DriveServer.GetModifiedAttributes(ThisObject);
		If ModifiedAttributes.Count() = 1
			And ModifiedAttributes[0] = "Description" Then
			Return;
		EndIf;
			
		ErrorTemplate = NStr("en = 'Cannot save the changes. ""%1"" is already selected in the settings of default accounts.'; ru = 'Не удалось сохранить изменения. ""%1"" уже указан в настройках счетов по умолчанию.';pl = 'Nie można zapisać zmian. ""%1"" jest już wybrany w ustawieniach domyślnych kont.';es_ES = 'No se pueden guardar los cambios. ""%1"" ya está seleccionado en la configuración de las cuentas por defecto.';es_CO = 'No se pueden guardar los cambios. ""%1"" ya está seleccionado en la configuración de las cuentas por defecto.';tr = 'Değişiklikler kaydedilemiyor. ""%1"", varsayılan hesapların ayarlarında zaten seçili.';it = 'Impossibile salvare le modifiche. ""%1"" è già selezionato nelle impostazioni dei conti predefiniti.';de = 'Fehler beim Speichern von Änderungen. ""%1"" ist bereits in den Einstellungen von Standardkonten ausgewählt.'");
		ErrorMessage = StrTemplate(ErrorTemplate, Ref);
		DriveServer.ShowMessageAboutError(ThisObject, ErrorMessage, , , , Cancel);
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf