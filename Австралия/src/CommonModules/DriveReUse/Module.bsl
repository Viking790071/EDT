#Region ExportProceduresAndFunctions

// Get value of Session current date
//
Function GetSessionCurrentDate() Export
	
	Return CurrentSessionDate();
	
EndFunction

// Function returns default value for transferred user and setting.
//
// Parameters:
//  User - current user
//  of application Setup    - a flag for which default value is returned
//
// Returns:
//  Value by default for setup.
//
Function GetValueByDefaultUser(User, Setting, EmptyValue = Undefined) Export

	Query = New Query;
	Query.SetParameter("User"   , User);
	Query.SetParameter("Setting", ChartsOfCharacteristicTypes.UserSettings[Setting]);
	Query.Text = "
	|SELECT ALLOWED
	|	Value
	|FROM
	|	InformationRegister.UserSettings AS RegisterRightsValue
	|
	|WHERE
	|	User = &User
	| AND Setting    = &Setting";

	Selection = Query.Execute().Select();

	If EmptyValue = Undefined Then
		EmptyValue = ChartsOfCharacteristicTypes.UserSettings[Setting].ValueType.AdjustValue();
	EndIf;

	If Selection.Count() = 0 Then
		
		Return EmptyValue;

	ElsIf Selection.Next() Then

		If Not ValueIsFilled(Selection.Value) Then
			Return EmptyValue;
		Else
			Return Selection.Value;
		EndIf;

	Else
		Return EmptyValue;

	EndIf;

EndFunction

// Function returns default value for transferred user and setting.
//
// Parameters:
//  Setting    - a flag for which default value is returned
//
// Returns:
//  Value by default for setup.
//
Function GetValueOfSetting(Setting) Export

	Query = New Query;
	Query.SetParameter("User", Users.CurrentUser());
	Query.SetParameter("Setting"   , ChartsOfCharacteristicTypes.UserSettings[Setting]);
	Query.Text = "
	|SELECT ALLOWED
	|	Value
	|FROM
	|	InformationRegister.UserSettings AS RegisterRightsValue
	|
	|WHERE
	|	User = &User
	| AND Setting    = &Setting";

	Selection = Query.Execute().Select();

	EmptyValue = ChartsOfCharacteristicTypes.UserSettings[Setting].ValueType.AdjustValue();

	If Selection.Count() = 0 Then
		
		Return EmptyValue;

	ElsIf Selection.Next() Then

		If Not ValueIsFilled(Selection.Value) Then
			Return EmptyValue;
		Else
			Return Selection.Value;
		EndIf;

	Else
		Return EmptyValue;

	EndIf;

EndFunction

// Returns True or False - specified setting of user is in the header.
//
// Parameters:
//  Setting    - a flag for which default value is returned
//
// Returns:
//  Value by default for setup.
//
Function AttributeInHeader(Setting) Export

	Query = New Query;
	Query.SetParameter("User", Users.CurrentUser());
	Query.SetParameter("Setting"   , ChartsOfCharacteristicTypes.UserSettings[Setting]);
	Query.Text = "
	|SELECT ALLOWED
	|	Value
	|FROM
	|	InformationRegister.UserSettings AS RegisterRightsValue
	|
	|WHERE
	|	User = &User
	| AND Setting    = &Setting";

	Selection = Query.Execute().Select();

	DefaultValue = True;

	If Selection.Count() = 0 Then
		
		Return DefaultValue;

	ElsIf Selection.Next() Then

		If Not ValueIsFilled(Selection.Value) Then
			Return DefaultValue;
		Else
			Return Selection.Value = Enums.AttributeStationing.InHeader;
		EndIf;

	Else
		Return DefaultValue;

	EndIf;

EndFunction

// Function returns the flag of commercial equipment use.
//
Function UsePeripherals() Export
	
	 Return GetFunctionalOption("UsePeripherals")
		   AND TypeOf(Users.AuthorizedUser()) = Type("CatalogRef.Users");
	 
EndFunction

// Function receives parameters of CR cash register.
//
Function CashRegistersGetParameters(CashCR) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	CASE
	|		WHEN CashRegisters.CashCRType = VALUE(Enum.CashRegisterTypes.FiscalRegister)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS IsFiscalRegister,
	|	CashRegisters.Peripherals AS DeviceIdentifier,
	|	CashRegisters.UseWithoutEquipmentConnection AS UseWithoutEquipmentConnection
	|FROM
	|	Catalog.CashRegisters AS CashRegisters
	|WHERE
	|	CashRegisters.Ref = &Ref";
	
	Query.SetParameter("Ref", CashCR);
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	If Selection.Next() Then
		
		Return New Structure(
			"DeviceIdentifier,
			|UseWithoutEquipmentConnection,
			|ThisIsFiscalRegister",
			Selection.DeviceIdentifier,
			Selection.UseWithoutEquipmentConnection,
			Selection.IsFiscalRegister
		);
		
	Else
		
		Return New Structure(
			"DeviceIdentifier,
			|UseWithoutEquipmentConnection,
			|ThisIsFiscalRegister",
			Catalogs.Peripherals.EmptyRef(),
			False,
			False
		);
		
	EndIf;
	
EndFunction

// Function checks if it is necessary to monitor the contracts of counterparties.
//
Function CounterpartyContractsControlNeeded() Export
	
	SetPrivilegedMode(True);
	
	If (Not Common.DataSeparationEnabled() And Not GetFunctionalOption("UseDataSynchronization")) Then
		ControlNeeded = False;
	Else
		ControlNeeded = True;
	EndIf;
	
	Return ControlNeeded;
	
EndFunction

// Function returns the value of advances offset setup.
//
// Parameters:
//  Setting    - a flag for which default value is returned
//
// Returns:
//  Value by default for setup.
//
Function GetAdvanceOffsettingSettingValue() Export
	
	OffsetAutomatically = GetValueOfSetting("SetOffAdvancePaymentsAutomatically");
	If Not ValueIsFilled(OffsetAutomatically) Then
		OffsetAutomatically = Constants.SetOffAdvancePaymentsAutomatically.Get();
	EndIf;
	
	Return OffsetAutomatically;
	
EndFunction

// Function determines for which operation mode of the application synchronization settings should be used.
//
Function SettingsForSynchronizationSaaS() Export

	Return GetFunctionalOption("StandardSubsystemsSaaS");

EndFunction

Function GetCurrentUserLanguageCode() Export
	
	CurrentUser = InfobaseUsers.CurrentUser();
	Return ?(CurrentUser.Language = Undefined, Metadata.DefaultLanguage.LanguageCode, CurrentUser.Language.LanguageCode);	
	
EndFunction

Function GetUserDefaultCompany() Export
	
	Company = GetValueByDefaultUser(UsersClientServer.AuthorizedUser(), "MainCompany");
	If Not ValueIsFilled(Company) Then 
		Company = Catalogs.Companies.EmptyRef();
	EndIf;
	
	Return Company;
	
EndFunction

// PROCEDURES AND FUNCTIONS FOR WORK WITH VAT RATES

// Get value of VAT rate.
//
Function GetVATRateValue(VATRate) Export
	
	Return ?(ValueIsFilled(VATRate), Common.ObjectAttributeValue(VATRate, "Rate"), 0);

EndFunction

// PROCEDURES AND FUNCTIONS FOR WORK WITH CONSTANTS

// Function returns the functional currency
//
Function GetFunctionalCurrency() Export
	
	Return Constants.FunctionalCurrency.Get();
	
EndFunction

// Function returns the state in progress for sales orders
//
Function GetStatusInProcessOfSalesOrders() Export
	
	Return Constants.SalesOrdersInProgressStatus.Get();
	
EndFunction

// Function returns the state completed for sales orders
//
Function GetStatusCompletedSalesOrders() Export
	
	Return Constants.StateCompletedSalesOrders.Get();
	
EndFunction

// Function returns the state in progress for sales orders
//
Function GetStatusInProcessOfWorkOrders() Export
	
	SetPrivilegedMode(True);
	Return Constants.WorkOrdersInProgressStatus.Get();
	
EndFunction

// Function returns the state completed for sales orders
//
Function GetStatusCompletedWorkOrders() Export
	
	SetPrivilegedMode(True);
	Return Constants.StateCompletedWorkOrders.Get();
	
EndFunction

Function GetOrderStatus(CatalogName, StatusName) Export
	
	Query = New Query;
	Query.SetParameter("OrderStatus", Enums.OrderStatuses[StatusName]);
	QueryText = 
	"SELECT TOP 1
	|	OrderStatuses.Ref AS Status
	|FROM
	|	&CatalogTable AS OrderStatuses
	|WHERE
	|	OrderStatuses.OrderStatus = &OrderStatus
	|	AND NOT OrderStatuses.DeletionMark";
	
	Query.Text = StrReplace(QueryText, "&CatalogTable", "Catalog." + CatalogName);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		Return Selection.Status;
	Else
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Status with purpose %1 is not found.'; ru = 'Не найден статус с назначением %1.';pl = 'Stan z celem %1 nie został znaleziony.';es_ES = 'Estado con propósito %1 no encontrado.';es_CO = 'Estado con propósito %1 no encontrado.';tr = ' %1 amacı olan durum bulunamadı.';it = 'Lo stato con scopo %1 non è stato trovato.';de = 'Status mit Zweck %1 wird nicht gefunden.'"), Enums.OrderStatuses[StatusName]);
	EndIf;
	
EndFunction

#EndRegion
