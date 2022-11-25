#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Function AccountingRegisterName(TypeOfEntries = Undefined) Export

	If TypeOfEntries = Enums.ChartsOfAccountsTypesOfEntries.Compound Then
		Return "AccountingJournalEntriesCompound"
	ElsIf TypeOfEntries = Enums.ChartsOfAccountsTypesOfEntries.Simple Then
		Return "AccountingJournalEntriesSimple"
	Else
		Raise NStr("en = 'Incorrect type of entries. Cannot resolve register name.'; ru = 'Неверный тип проводок. Не удалось разрешить имя регистра.';pl = 'Niepoprawny typ wpisów. Nie można rozpoznać nazwy rejestru.';es_ES = 'Tipo de entradas de diario incorrecto. No se puede resolver el nombre del registro.';es_CO = 'Tipo de entradas de diario incorrecto. No se puede resolver el nombre del registro.';tr = 'Yanlış giriş türü. Kayıt adı çözümlenemiyor.';it = 'Tipo di voci errato. Impossibile risolvere il nome registro.';de = 'Inkorrekter Buchungstyp. Fehler beim Lösen des Registernamens.'");
	EndIf;	

EndFunction

Function CheckCodeIsUnique(CurrentObjectRef, CurrentObjectCode, CurrentChartOfAccounts) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT DISTINCT
	|	MasterChartOfAccounts.Ref AS RefCount
	|FROM
	|	ChartOfAccounts.MasterChartOfAccounts AS MasterChartOfAccounts
	|WHERE
	|	MasterChartOfAccounts.Code = &Code
	|	AND MasterChartOfAccounts.ChartOfAccounts = &ChartOfAccounts
	|	AND MasterChartOfAccounts.Ref <> &Ref";
	
	Query.SetParameter("Ref",				CurrentObjectRef);
	Query.SetParameter("Code",				CurrentObjectCode);
	Query.SetParameter("ChartOfAccounts",	CurrentChartOfAccounts);
	
	QueryResult = Query.Execute();
	
	Return QueryResult.IsEmpty();
	
EndFunction

Procedure AddInformationWithCheck(ParametersStructure, BackgroundJobStorageAddress = "") Export
	
	AccountsTable = Undefined;
	
	If Not ParametersStructure.Property("AccountsTable", AccountsTable) Then
		Return;
	EndIf;
	
	NewAccountParameters = ParametersStructure.NewAccountParameters;
	
	For Each AccountRow In AccountsTable Do
		
		If AccountRow.Error = 0 Then // Account already processed
			Continue;
		EndIf;
		
		AccountRow.Error = RunAccountCheck(AccountRow.AccountRef, NewAccountParameters);
		
	EndDo;
	
	ResultStructure = New Structure();
	ResultStructure.Insert("Messages", TimeConsumingOperations.UserMessages(True));
	ResultStructure.Insert("AccountsTable", AccountsTable);
	
	PutToTempStorage(ResultStructure, BackgroundJobStorageAddress);

EndProcedure

// Function returns the list of the "key" attributes names.
//
Function GetObjectAttributesBeingLocked() Export
	
	Result = New Array;
	
	Return Result;
	
EndFunction

Function FindByCodeAndChartOfAccounts(Code, ChartOfAccountsRef) Export

	If Not ValueIsFilled(Code) Or Not ValueIsFilled(ChartOfAccountsRef) Then
		Return ChartsOfAccounts.MasterChartOfAccounts.EmptyRef();
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED TOP 1
	|	MasterChartOfAccounts.Ref AS Ref
	|FROM
	|	ChartOfAccounts.MasterChartOfAccounts AS MasterChartOfAccounts
	|WHERE
	|	MasterChartOfAccounts.Code = &Code
	|	AND MasterChartOfAccounts.ChartOfAccounts = &ChartOfAccounts";
	
	Query.SetParameter("ChartOfAccounts", ChartOfAccountsRef);
	Query.SetParameter("Code"			, Code);
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return ChartsOfAccounts.MasterChartOfAccounts.EmptyRef();
	EndIf;
	
	SelectionDetailRecords = QueryResult.Select();
	SelectionDetailRecords.Next();
	
	Return SelectionDetailRecords.Ref;

EndFunction

Function FindByDescriptionAndChartOfAccounts(Description, ChartOfAccountsRef) Export

	If Not ValueIsFilled(Description) Or Not ValueIsFilled(ChartOfAccountsRef) Then
		Return ChartsOfAccounts.MasterChartOfAccounts.EmptyRef();
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED TOP 1
	|	MasterChartOfAccounts.Ref AS Ref
	|FROM
	|	ChartOfAccounts.MasterChartOfAccounts AS MasterChartOfAccounts
	|WHERE
	|	MasterChartOfAccounts.ChartOfAccounts = &ChartOfAccounts
	|	AND MasterChartOfAccounts.Description = &Description";
	
	Query.SetParameter("ChartOfAccounts", ChartOfAccountsRef);
	Query.SetParameter("Description"	, Description);
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return ChartsOfAccounts.MasterChartOfAccounts.EmptyRef();
	EndIf;
	
	SelectionDetailRecords = QueryResult.Select();
	SelectionDetailRecords.Next();
	
	Return SelectionDetailRecords.Ref;

EndFunction

Function MaxAnalyticalDimensionsNumber() Export

	Return 4;

EndFunction

Function GetChildAccountsArray(ChartOfAccounts) Export

	Query = New Query;
	Query.Text = 
	"SELECT
	|	MasterChartOfAccounts.Ref AS Ref
	|FROM
	|	ChartOfAccounts.MasterChartOfAccounts AS MasterChartOfAccounts
	|WHERE
	|	MasterChartOfAccounts.Parent = &ChartOfAccounts";
	
	Query.SetParameter("ChartOfAccounts", ChartOfAccounts);
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	ChildArray = New Array;
	
	While Selection.Next() Do
		ChildArray.Add(Selection.Ref);
	EndDo;
	
	Return ChildArray;
	
EndFunction

Procedure FillExtDimensionTypesByAnalyticalDimensions(AnalyticalDimensions, ExtDimensionTypes, UseQuantity, Currency) Export

	ExtDimensionTypes.Clear();
	For Each Row In AnalyticalDimensions Do
		
		NewRow = ExtDimensionTypes.Add();
		NewRow.ExtDimensionType	 = Row.AnalyticalDimension;
		NewRow.Quantity			 = UseQuantity;
		NewRow.Currency			 = Currency;
		
	EndDo;

EndProcedure

Procedure CheckActivityPeriod(Account, CheckParent, CheckPeriod, ModifiedCompanies, Cancel) Export

	If ValueIsFilled(Account.Parent) And (CheckParent Or CheckPeriod) Then
	
		ParentDates		= Common.ObjectAttributesValues(Account.Parent, "StartDate, EndDate");
		ParentEndDate	= ?(ParentDates.EndDate = '00010101', '39991231', ParentDates.EndDate);
		AccountEndDate	= ?(Account.EndDate = '00010101', '39991231', Account.EndDate);
		
		If Account.StartDate < ParentDates.StartDate
			Or Account.EndDate > ParentEndDate Then
			
			MessageText = NStr("en = 'Cannot save the changes. The validity period of the “Subordinate to” account (%1 - %2) is less than the validity period of this account (%3 - %4).'; ru = 'Не удалось сохранить изменения. Срок действия подчиненного счета (%1 - %2) меньше срока действия данного счета (%3 - %4).';pl = 'Nie można zapisać zmian. Okres ważności konta “Podporządkowany” (%1 - %2) jest mniejszy niż okres ważności okresu tego konta (%3 - %4).';es_ES = 'No se pueden guardar los cambios. El periodo de validez de la cuenta ""Subordinar a"" (%1 -%2 ) es menor que el periodo de validez de esta cuenta ( %3-%4 ).';es_CO = 'No se pueden guardar los cambios. El periodo de validez de la cuenta ""Subordinar a"" (%1 -%2 ) es menor que el periodo de validez de esta cuenta ( %3-%4 ).';tr = 'Değişiklikler kaydedilemiyor. ""Üst hesabın"" geçerlilik dönemi (%1 - %2) bu hesabın geçerlilik döneminden (%3 - %4) daha önce.';it = 'Impossibile salvare le modifiche. Il periodo di validità del conto ""Subordinato a"" (%1 - %2) è precedente al periodo di validità di questo conto (%3 - %4).';de = 'Fehler beim Speichern von Änderungen. Die Gültigkeitsdauer des Kontos “Untergeordnet dem” (%1 - %2) ist kürzer als die Gültigkeitsdauer dieses Kontos(%3 - %4).'");	
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				MessageText,
				Format(ParentDates.StartDate, "DLF=D; DE=..."),
				Format(ParentDates.EndDate	, "DLF=D; DE=..."),
				Format(Account.StartDate	, "DLF=D; DE=..."),
				Format(Account.EndDate		, "DLF=D; DE=..."));
				
			CommonClientServer.MessageToUser(MessageText, , "Object.StartDate", , Cancel); 
			
		EndIf;
		
	EndIf;
	
	If CheckPeriod Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("ChartOfAccounts", Account.Ref);
		ParametersStructure.Insert("StartDate"		, Account.StartDate);
		ParametersStructure.Insert("EndDate"		, Account.EndDate);
		
		WorkWithArbitraryParameters.CheckExistTemplatesWithCompany(ParametersStructure, Cancel);
		WorkWithArbitraryParameters.CheckExistDefaultAccountsWithCompany(ParametersStructure, Cancel);
		
	EndIf;
	
	For Each ModifiedCompany In ModifiedCompanies Do
		
		CompanyRow = Account.Companies[ModifiedCompany.Index];
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("ChartOfAccounts", Account.Ref);
		ParametersStructure.Insert("StartDate"		, CompanyRow.StartDate);
		ParametersStructure.Insert("EndDate"		, CompanyRow.EndDate);
		ParametersStructure.Insert("Company"		, CompanyRow.Company);
		ParametersStructure.Insert("Index"			, ModifiedCompany.Index);
		
		WorkWithArbitraryParameters.CheckExistTemplatesWithCompany(ParametersStructure, Cancel);
		
	EndDo;
	
EndProcedure

Function SelectAllowedCompaniesFromTable(CompaniesTable) Export
	
	Query = New Query;
	
	Query.Text = 
	"SELECT ALLOWED
	|	MasterChartOfAccountsCompanies.LineNumber AS LineNumber,
	|	MasterChartOfAccountsCompanies.Company AS Company,
	|	MasterChartOfAccountsCompanies.StartDate AS StartDate,
	|	MasterChartOfAccountsCompanies.EndDate AS EndDate
	|INTO AccountCompanies
	|FROM
	|	&CompaniesTable AS MasterChartOfAccountsCompanies
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AccountCompanies.LineNumber AS LineNumber,
	|	AccountCompanies.Company AS Company,
	|	AccountCompanies.StartDate AS StartDate,
	|	AccountCompanies.EndDate AS EndDate
	|FROM
	|	AccountCompanies AS AccountCompanies";
	
	Query.SetParameter("CompaniesTable", CompaniesTable);
	
	QueryResult = Query.Execute();
	
	Return QueryResult.Unload();
	
EndFunction

#EndRegion

#Region EventHandlers

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	StandardProcessing = False;
	Fields.Add("Code");
	Fields.Add("Description");
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	StandardProcessing = False;
	Presentation = StrTemplate("%1 %2", Data.Code, ?(IsBlankString(Presentation), Data.Description, Presentation));
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);

EndProcedure

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	Var Date, Company, ChartOfAccounts;
	
	If Parameters.Filter.Property("Date", Date)
		And Parameters.Filter.Property("Company", Company)
		And Parameters.Filter.Property("ChartOfAccounts", ChartOfAccounts) Then
		
		Parameters.Filter.Insert("Ref", MasterAccounting.GetAccountChoiceList(Company, ChartOfAccounts, Date));
		
	EndIf;
	
	NativeLanguagesSupportServer.ChoiceDataGetProcessing(
		ChoiceData,
		Parameters,
		StandardProcessing,
		Metadata.ChartsOfAccounts.MasterChartOfAccounts);
	
EndProcedure

#EndRegion

#Region Private

Function RunAccountCheck(Account, NewAccountParameters)

	AccountObject = Account.GetObject();
	
	If NewAccountParameters.Operation = "AddCompany" Then
		
		FillPropertyValues(AccountObject.Companies.Add(), NewAccountParameters);
		
	ElsIf NewAccountParameters.Operation = "ChangeAccountPeriod" Then
		
		FillPropertyValues(AccountObject, NewAccountParameters);
		
	ElsIf NewAccountParameters.Operation = "ChangeCompanyPeriod" Then
		
		ChangeTSCompanyPeriod(AccountObject, NewAccountParameters);
		
	EndIf;
	
	CorrectFilling = AccountObject.CheckFilling();
	
	If CorrectFilling Then
		Try
			AccountObject.Write();
		Except
			
			MessageText = StrTemplate(NStr("en = 'Cannot update account. %1'; ru = 'Не удалось обновить счет. %1';pl = 'Nie można zaktualizować konta. %1';es_ES = 'No se puede actualizar la cuenta.%1';es_CO = 'No se puede actualizar la cuenta.%1';tr = 'Hesap güncellenmedi. %1';it = 'Impossibile aggiornare il conto.%1';de = 'Fehler beim Aktualisieren des Kontos. %1'"), DetailErrorDescription(ErrorInfo()));
			EventName = AccountingTemplatesPosting.GetEventGroupVariant()
				+ NStr("en = 'Account update'; ru = 'Обновление счета';pl = 'Aktualizacja konta';es_ES = 'Actualizar la cuenta';es_CO = 'Actualizar la cuenta';tr = 'Hesap güncellemesi';it = 'Aggiornamento conto';de = 'Aktualisieren des Kontos'", CommonClientServer.DefaultLanguageCode());
				
			WriteLogEvent(EventName, EventLogLevel.Error, Account, , MessageText);
			
			Return 1;
			
		EndTry;
		
		Return 0;
	Else
		Return 1;
	EndIf;
	
EndFunction 

Procedure ChangeTSCompanyPeriod(AccountObject, Parameters)
	
	FilterCompany = New Structure("Company", Parameters.Company);
	
	TSRows = AccountObject.Companies.FindRows(FilterCompany);

	For Each CompanyRow In TSRows Do
		FillPropertyValues(CompanyRow, Parameters);
	EndDo;

EndProcedure

#EndRegion

#EndIf