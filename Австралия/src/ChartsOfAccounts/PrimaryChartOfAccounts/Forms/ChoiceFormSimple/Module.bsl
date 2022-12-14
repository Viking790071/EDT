
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	IncludeCostOfOther		= False;
	IncludeInIncomeOther	= False;
	
	// To display other expenses together with the principal expenses.
	If Parameters.Property("IncludeCostOfOther") Then
		IncludeCostOfOther = Parameters.IncludeCostOfOther;
	EndIf;
	
	// To display other income together with the principal one.
	If Parameters.Property("IncludeInIncomeOther") Then
		IncludeInIncomeOther = Parameters.IncludeInIncomeOther;
	EndIf;
	
	// To change the form header.
	If Parameters.Property("InvoiceHeader") Then
		Title = Parameters.InvoiceHeader;
	EndIf;
	
	// To change the form header.
	If Parameters.Property("ExcludePredefinedAccount") Then
		ExcludePredefinedAccount = Parameters.ExcludePredefinedAccount;
	EndIf;

	If Parameters.Property("CurrentRow") Then
		CurrentRow = Parameters.CurrentRow;
	EndIf;
	
	If Parameters.Property("Filter")
		AND Parameters.Filter.Count() > 0 Then
			Filter = Parameters.Filter;
	Else
		ShowAllAccounts					= True;
		Items.ShowAllAccounts.Visible	= False;
	EndIf;
	
	If Parameters.Property("NotShowAllAccounts")
		And Parameters.NotShowAllAccounts Then
		Items.ShowAllAccounts.Visible	= False;
	EndIf;
	
	If Parameters.Property("AllowHeaderAccountsSelection") Then
		AllowHeaderAccountsSelection = Parameters.AllowHeaderAccountsSelection;
	EndIf;
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	ShowAllAccountsOnChange(Undefined);
EndProcedure

#EndRegion

#Region FormItemsEventsHandlers

&AtClient
Procedure HierarchyOnActivateRow(Item)
	
	If Items.Hierarchy.CurrentData <> Undefined
		AND CurHierarchy <> Items.Hierarchy.CurrentData.Value Then
		
		SetFilterOnClient(Items.Hierarchy.CurrentData.Value);
		CurHierarchy = Items.Hierarchy.CurrentData.Value;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowAllAccountsOnChange(Item)
	
	If ShowAllAccounts Then	
		ShowAllAccountsAtServer();		
	Else
		CurHierarchy = Undefined;
		Items.DistributionDirection.Visible = True;
		SetFilter();
	EndIf;
	
EndProcedure

#EndRegion

#Region ListFormTableItemsEventHandlers

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Not AllowHeaderAccountsSelection Then
		
		ListRow = Item.RowData(SelectedRow);
		
		If Not ListRow = Undefined Then
			
			If ListRow.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.Header") Then
				
				StandardProcessing = False;
				
				If Items.List.Representation = TableRepresentation.HierarchicalList Then
					Item.CurrentParent = NewParent(Item.CurrentParent, SelectedRow);
				EndIf;
				
				If Items.List.Representation = TableRepresentation.Tree Then
					If Item.Expanded(SelectedRow) Then
						Item.Collapse(SelectedRow);
					Else
						Item.Expand(SelectedRow);
					EndIf;
				EndIf;
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ListValueChoice(Item, Value, StandardProcessing)
	
	If Not AllowHeaderAccountsSelection Then
		
		ListRow = Item.RowData(Value);
		
		If Not ListRow = Undefined Then
			
			If ListRow.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.Header") Then
				
				StandardProcessing = False;
				
				MessageText = NStr(
					"en = 'Select an item, not a group.
					|To expand a group use ""Ctrl"" and the Up Arrow and Down Arrow keys or ""+"" and ""-"" keys on the number pad.'; 
					|ru = '???????????????? ??????????????, ?? ???? ????????????.
					|?????????????????????? ???????????????????? ""Ctrl"" ?? ?????????????? ?????????? ?????? ?????????????? ????????, ?????? ???????????? + ?? - ???? ???????????????? ???????????? ?????? ????????, ?????????? ?????????????????????? ?? ?????????????????????????? ????????????.';
					|pl = 'Wybierz element, a nie grup??.
					|Aby rozwin???? grup??, u??yj klawiszy ""Ctrl"" i strza??ek ""w g??r??"" i ""w d????"" lub klawiszy ""+"" i ""-"" na klawiaturze numerycznej.';
					|es_ES = 'Seleccione un elemento en vez de grupo.
					|Para maximizar el grupo use ""Ctrl"" y las teclas flecha arriba o flecha abajo o las teclas ""+"" y ""-"" en el teclado num??rico.';
					|es_CO = 'Seleccione un elemento en vez de grupo.
					|Para maximizar el grupo use ""Ctrl"" y las teclas flecha arriba o flecha abajo o las teclas ""+"" y ""-"" en el teclado num??rico.';
					|tr = 'Bir kalem se??in, grup de??il. 
					| Bir grubu geni??letmek i??in ""Ctrl"" ve Yukar?? Ok ve A??a???? Ok tu??lar??n?? veya say?? tu?? tak??m??ndaki ""+"" ve ""-"" tu??lar??n?? kullan??n.';
					|it = 'Selezionare un elemento, non un gruppo.
					|Per espandere un gruppo utilizzare ""Ctrl"" e la freccia in alto e basso o i tasti ""+"" o ""-"" nel tastierino numerico.';
					|de = 'W??hlen Sie ein Element aus, nicht eine Gruppe.
					|Um eine Gruppe zu erweitern, verwenden Sie ""Strg"" und die Pfeiltasten nach oben und unten oder die Tasten ""+"" und ""-"" im Nummernblock.'");
				
				ShowMessageBox(Undefined, MessageText);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// Procedure set conditional appearance
//
&AtServer
Procedure SetConditionalAppearance()
	
	ColorHeaderGLA = StyleColors.HeaderGLAccounts;
	
	ConditionalAppearance.Items.Clear();
	
	// MethodOfDistribution
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.MethodOfDistribution.Name);
	
	ListCurHierarchy = New ValueList;
	ListCurHierarchy.Add(Enums.GLAccountsTypes.IndirectExpenses);
	ListCurHierarchy.Add(Enums.GLAccountsTypes.WorkInProgress);
	ListCurHierarchy.Add(Enums.GLAccountsTypes.Revenue);
	ListCurHierarchy.Add(Enums.GLAccountsTypes.OtherIncome);
	ListCurHierarchy.Add(Enums.GLAccountsTypes.LoanInterest);
	ListCurHierarchy.Add(Enums.GLAccountsTypes.OtherExpenses);
	ListCurHierarchy.Add(Enums.GLAccountsTypes.Expenses);
	
	FilterItem					= Item.Filter.Items.Add((Type("DataCompositionFilterItem")));
	FilterItem.LeftValue		= New DataCompositionField("CurHierarchy");
	FilterItem.ComparisonType	= DataCompositionComparisonType.NotInList;
	FilterItem.RightValue		= ListCurHierarchy;
	
	Item.Appearance.SetParameterValue("Visible", False);
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.MethodOfDistribution.Name);
	
	FilterItemsAndGroup = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterItemsAndGroup.GroupType = DataCompositionFilterItemsGroupType.AndGroup;
	
	ItemFilter = FilterItemsAndGroup.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("List.MethodOfDistribution");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Enums.CostAllocationMethod.DoNotDistribute;
	
	ListTypeOfAccount = New ValueList;
	ListTypeOfAccount.Add(Enums.GLAccountsTypes.Revenue);
	ListTypeOfAccount.Add(Enums.GLAccountsTypes.Expenses);
	ListTypeOfAccount.Add(Enums.GLAccountsTypes.OtherIncome);
	ListTypeOfAccount.Add(Enums.GLAccountsTypes.OtherExpenses);
	ListTypeOfAccount.Add(Enums.GLAccountsTypes.LoanInterest);
	
	ItemFilter = FilterItemsAndGroup.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("List.TypeOfAccount");
	ItemFilter.ComparisonType = DataCompositionComparisonType.InList;
	ItemFilter.RightValue = ListTypeOfAccount;
	
	Item.Appearance.SetParameterValue("Text", NStr("en = 'Direct Distribution'; ru = '???????????????????????????????? ??????????????????????????';pl = 'Dystrybucja bezpo??rednia';es_ES = 'Distribuci??n directa';es_CO = 'Distribuci??n directa';tr = 'Direkt da????t??m';it = 'Distribuzione diretta';de = 'Direkte Verteilung'"));
	
	// List
	
	ItemAppearance = List.ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("TypeOfAccount");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= Enums.GLAccountsTypes.Header;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("BackColor", ColorHeaderGLA);
	
EndProcedure

&AtServerNoContext
Function NewParent(CurrentParent, CurrentItem)
	
	CurrentItemParent = Common.ObjectAttributeValue(CurrentItem, "Parent");
	
	If Not ValueIsFilled(CurrentItemParent) Then
		CurrentItemParent = Undefined;
	EndIf;
		
	If CurrentParent = CurrentItemParent Then
		Return CurrentItem;
	Else
		Return CurrentItemParent;
	EndIf;
	
EndFunction

&AtServer
Procedure AddHierarchy(GLAccountsTypes = Undefined, TypeOfAccount = Undefined)
	
	UseProductionSubsystem = Constants.UseProductionSubsystem.Get();
	
	Ct = 0;
	CurHierarchyRow = 0;
	
	If TypeOf(GLAccountsTypes) = Type("FixedArray") Then
		For Each CurAccountType In GLAccountsTypes Do
			InvoiceHeader = "";
			If CurAccountType = Enums.GLAccountsTypes.Expenses Then
				InvoiceHeader = NStr("en = 'Expenses allocated to the financial result (Indirect)'; ru = '??????????????, ???????????????????????????? ???? ???????????????????? ?????????????????? (??????????????????)';pl = 'Koszty przydzielane??do wyniku finansowego (po??rednie)';es_ES = 'Gastos asignados al resultado financiero (Indirectos)';es_CO = 'Gastos asignados al resultado financiero (Indirectos)';tr = 'Finansal sonuca da????t??lan giderler (Dolayl??)';it = 'Spese assegnate al risultato finanziario (indirette)';de = 'Dem Finanzergebnis zugewiesene Ausgaben (Indirekt)'");
			ElsIf CurAccountType = Enums.GLAccountsTypes.OtherExpenses Then
				InvoiceHeader = NStr("en = 'Other expenses allocated to the financial result'; ru = '???????????? ??????????????, ???????????????????????????? ???? ???????????????????? ??????????????????';pl = 'Pozosta??e koszty przydzielone??do wyniku finansowego';es_ES = 'Otros gastos asignados al resultado financiero';es_CO = 'Otros gastos asignados al resultado financiero';tr = 'Finansal sonuca da????t??lan di??er giderler';it = 'Altre spese assegnate al risultato finanziario';de = 'Sonstige dem Finanzergebnis zugewiesene Ausgaben'");
			ElsIf  CurAccountType = Enums.GLAccountsTypes.Revenue Then
				InvoiceHeader = NStr("en = 'Income allocated to the financial result'; ru = '????????????, ???????????????????????????? ???? ???????????????????? ??????????????????';pl = 'Doch??d przydzielony do wyniku finansowego';es_ES = 'Ingreso asignado al resultado financiero';es_CO = 'Ingreso asignado al resultado financiero';tr = 'Finansal sonuca da????t??lan gelir';it = 'Entrate assegnate al risultato finanziario';de = 'Dem Finanzergebnis zugewiesene Einnahmen'");
			ElsIf CurAccountType = Enums.GLAccountsTypes.OtherIncome Then
				InvoiceHeader = NStr("en = 'Other income allocated to the financial result'; ru = '???????????? ????????????, ???????????????????????????? ???? ???????????????????? ??????????????????';pl = 'Pozosta??e dochody przydzielone do wyniku finansowego';es_ES = 'Otro ingreso asignado al resultado financiero';es_CO = 'Otro ingreso asignado al resultado financiero';tr = 'Finansal sonuca da????t??lan di??er gelir';it = 'Altri proventi assegnati al risultato finanziario';de = 'Sonstige dem Finanzergebnis zugewiesene Einnahmen'");
			ElsIf CurAccountType = Enums.GLAccountsTypes.AccountsReceivable Then
				InvoiceHeader = NStr("en = 'Other debtors (debt to us)'; ru = '???????????? ???????????????? (?????????????????????????? ?????????? ????????)';pl = 'Inni d??u??nicy (d??ug wobec nas)';es_ES = 'Otros deudores (deuda para nosotros)';es_CO = 'Otros deudores (deuda para nosotros)';tr = 'Di??er bor??lular (bize olan bor??)';it = 'Altri debitori (debito verso di noi)';de = 'Andere Debitoren (Schulden an uns)'");
			ElsIf CurAccountType = Enums.GLAccountsTypes.AccountsPayable Then
				InvoiceHeader = NStr("en = 'Other creditors (our debt)'; ru = '???????????? ?????????????????? (???????? ??????????????????????????)';pl = 'Inni wierzyciele (nasz d??ug)';es_ES = 'Otros acreedores (nuestra deuda)';es_CO = 'Otros acreedores (nuestra deuda)';tr = 'Di??er alacakl??lar (bizim borcumuz)';it = 'Altri creditori (nostro debito)';de = 'Andere Kreditoren (unsere Schulden)'");
			ElsIf CurAccountType = Enums.GLAccountsTypes.CashAndCashEquivalents Then
				InvoiceHeader = NStr("en = 'Funds transfer'; ru = '?????????????????????? ??????????';pl = 'Transfer funduszy';es_ES = 'Transferencia de fondos';es_CO = 'Transferencia de fondos';tr = 'Fon transferi';it = 'Trasferimento fondi';de = 'Geld??berweisung'");
			ElsIf CurAccountType = Enums.GLAccountsTypes.LongtermLiabilities Then
				InvoiceHeader = NStr("en = 'Long-term liabilities'; ru = '???????????????????????? ??????????????????????????';pl = 'D??ugoterminowe zobowi??zania';es_ES = 'Obligaciones a largo plazo';es_CO = 'Obligaciones a largo plazo';tr = 'Uzun vadeli y??k??ml??l??kler';it = 'Passivit?? a lungo termine';de = 'Langfristige Verbindlichkeiten'");
			ElsIf CurAccountType = Enums.GLAccountsTypes.Capital Then
				InvoiceHeader = NStr("en = 'Capital'; ru = '??????????????';pl = 'Kapita??';es_ES = 'Capital';es_CO = 'Capital';tr = 'Sermaye';it = 'Capitale sociale';de = 'Kapital'");
			ElsIf CurAccountType = Enums.GLAccountsTypes.LoansBorrowed Then
				InvoiceHeader = NStr("en = 'Credits and Loans'; ru = '?????????????? ?? ??????????';pl = 'Kredyty i po??yczki';es_ES = 'Cr??ditos y Pr??stamos';es_CO = 'Cr??ditos y Pr??stamos';tr = 'Krediler ve Bor??lar';it = 'Crediti e prestiti';de = 'Kredite und Darlehen'");
			ElsIf CurAccountType = Enums.GLAccountsTypes.WorkInProgress Then
				InvoiceHeader = NStr("en = 'Expenses related to product release (Direct)'; ru = '??????????????, ?????????????????????? ?? ?????????????? ?????????????????? (????????????)';pl = 'Koszty zwi??zane z wytworzeniem produktu (Bezpo??rednie)';es_ES = 'Gastos relacionados con el lanzamiento del producto (Directos)';es_CO = 'Gastos relacionados con el lanzamiento del producto (Directos)';tr = '??r??n imalat?? ile ilgili giderler (Direkt)';it = 'Spese relative al rilascio prodotto (Dirette)';de = 'Ausgaben im Zusammenhang mit der Produktfreigabe (Direkt)'");
			ElsIf CurAccountType = Enums.GLAccountsTypes.IndirectExpenses Then
				InvoiceHeader = NStr("en = 'Costs allocated to product release cost (Indirect)'; ru = '??????????????, ???????????????????????????? ???? ?????????????????????????? ?????????????? ?????????????????? (??????????????????)';pl = 'Koszty przypisane do koszt??w wytwarzania produktu (Po??rednie)';es_ES = 'Costes asignados al coste del lanzamiento del producto (Indirectos)';es_CO = 'Costes asignados al coste del lanzamiento del producto (Indirectos)';tr = '??r??n imalat maliyetine da????t??lan giderler (Dolayl??)';it = 'Costi imputati al costo di rilascio del prodotto (indiretto)';de = 'Den Produktfreigabekosten zugeordnete Kosten (Indirekt)'");
			ElsIf CurAccountType = Enums.GLAccountsTypes.OtherCurrentAssets Then
				InvoiceHeader = NStr("en = 'Other Current Assets'; ru = '???????????? ?????????????????? ????????????';pl = 'Inne aktywa obrotowe';es_ES = 'Otros activos actuales';es_CO = 'Otros activos actuales';tr = 'Di??er D??nen Varl??klar';it = 'Altre attivit?? correnti';de = 'Sonstige kurzfristige Verm??genswerte'");
			EndIf;
			If (UseProductionSubsystem
				  OR (CurAccountType <> Enums.GLAccountsTypes.WorkInProgress
					   AND CurAccountType <> Enums.GLAccountsTypes.IndirectExpenses))
			   AND (NOT IncludeCostOfOther
				  OR (IncludeCostOfOther
					   AND CurAccountType <> Enums.GLAccountsTypes.OtherExpenses))
			   AND (NOT IncludeInIncomeOther
				  OR (IncludeInIncomeOther
					   AND CurAccountType <> Enums.GLAccountsTypes.OtherIncome)) Then // adding hierarchy if the filter corresponds to conditions.
				Hierarchy.Add(CurAccountType, InvoiceHeader);
				If CurAccountType = TypeOfAccount
					OR (IncludeCostOfOther AND TypeOfAccount = Enums.GLAccountsTypes.OtherExpenses AND CurAccountType = Enums.GLAccountsTypes.Expenses)
					OR (IncludeInIncomeOther AND TypeOfAccount = Enums.GLAccountsTypes.OtherIncome AND CurAccountType = Enums.GLAccountsTypes.Revenue) Then
					CurHierarchyRow = Ct;
				EndIf;
				Ct = Ct + 1;
			EndIf;
		EndDo;
	ElsIf ValueIsFilled(GLAccountsTypes) Then
		Hierarchy.Add(GLAccountsTypes);
		CurHierarchyRow = 0;
	Else
		For Ct = 0 To Enums.GLAccountsTypes.Count() - 1 Do
			Hierarchy.Add(Enums.GLAccountsTypes[Ct]);
		EndDo;
		CurHierarchyRow = 0;
	EndIf;
	
	For Ct = 0 To Hierarchy.Count() - 1 Do
		Hierarchy[Ct].Picture = PictureLib.Folder;
	EndDo;
	
	Items.Hierarchy.CurrentRow = CurHierarchyRow;
	
EndProcedure

&AtClient
Procedure SetFilterOnClient(TypeOfAccount = Undefined)
	
	List.SettingsComposer.FixedSettings.Filter.Items.Clear();
	
	If ExcludePredefinedAccount Then
		
		FilterList = SetFilterOnServer(); // Accounts matching accumulation registers shall be excluded from the filter for other operations.
		
		FilterItem = List.SettingsComposer.FixedSettings.Filter.Items.Add(Type("DataCompositionFilterItem"));
		FilterItem.LeftValue		= New DataCompositionField("Ref");
		FilterItem.ComparisonType	= DataCompositionComparisonType.NotInList;
		FilterItem.Use			= True;
		FilterItem.RightValue		= FilterList;
		
	EndIf;
	
	If ValueIsFilled(TypeOfAccount) Then
		
		FilterItem = List.SettingsComposer.FixedSettings.Filter.Items.Add(Type("DataCompositionFilterItem"));
		FilterItem.LeftValue = New DataCompositionField("TypeOfAccount");
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.Use = True;
		
		If TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.Expenses")
			AND IncludeCostOfOther = True Then
			
			FilterList = New ValueList();
			FilterList.Add(PredefinedValue("Enum.GLAccountsTypes.Expenses"));
			FilterList.Add(PredefinedValue("Enum.GLAccountsTypes.OtherExpenses"));
			FilterItem.ComparisonType	= DataCompositionComparisonType.InList;
			FilterItem.RightValue		= FilterList;
			
		ElsIf TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.Revenue")
			AND IncludeInIncomeOther = True Then
			
			FilterList = New ValueList();
			FilterList.Add(PredefinedValue("Enum.GLAccountsTypes.Revenue"));
			FilterList.Add(PredefinedValue("Enum.GLAccountsTypes.OtherIncome"));
			FilterItem.ComparisonType	= DataCompositionComparisonType.InList;
			FilterItem.RightValue		= FilterList;
			
		Else
			FilterItem.RightValue = TypeOfAccount;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ShowAllAccountsAtServer()
	
	Items.DistributionDirection.Visible = False;
	Items.List.Representation			= TableRepresentation.HierarchicalList;
	
	List.SettingsComposer.FixedSettings.Filter.Items.Clear();
	List.Filter.Items.Clear();
	
EndProcedure

&AtServer
Procedure SetFilter()
	
	Hierarchy.Clear();
	List.SettingsComposer.FixedSettings.Filter.Items.Clear();
	Items.List.Representation = TableRepresentation.List;
	
	If ValueIsFilled(Filter) AND Filter.Property("TypeOfAccount") Then
		CommonClientServer.AddCompositionItem(List.Filter, "TypeOfAccount", DataCompositionComparisonType.Equal, Filter.TypeOfAccount,, True);
	EndIf;
	
	FilterItem = List.SettingsComposer.FixedSettings.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue		= New DataCompositionField("Ref");
	FilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	FilterItem.Use				= True;
		
	If ValueIsFilled(CurrentRow)
		AND TypeOf(CurrentRow) = Type("ChartOfAccountsRef.PrimaryChartOfAccounts")
		AND ValueIsFilled(Filter)
		AND Filter.Property("TypeOfAccount") Then // if the account is already selected.
		
		AddHierarchy(Filter.TypeOfAccount, CurrentRow.TypeOfAccount);
		FilterItem.RightValue = CurrentRow; // to exclude blinking at filter setting.
		
	ElsIf ValueIsFilled(Filter)
		AND Filter.Property("TypeOfAccount") Then // if the account isn't selected.
		
		AddHierarchy(Filter.TypeOfAccount);
		FilterItem.Use			= False;
		FilterItem.RightValue	= ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef(); // to exclude blinking at filter setting.
			
	Else
		
		AddHierarchy();
		FilterItem.RightValue = ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef();
		
	EndIf;	

EndProcedure

&AtServer
Function SetFilterOnServer()
	
	FilterList = New ValueList(); // Accounts matching accumulation registers shall be excluded from the filter for other operations.
	FilterList.Add(Catalogs.DefaultGLAccounts.GetDefaultGLAccount("BankAccount"));
	FilterList.Add(Catalogs.DefaultGLAccounts.GetDefaultGLAccount("PettyCashAccount"));
	FilterList.Add(Catalogs.DefaultGLAccounts.GetDefaultGLAccount("TaxPayable"));
	FilterList.Add(Catalogs.DefaultGLAccounts.GetDefaultGLAccount("TaxRefund"));
	FilterList.Add(Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AdvancesToSuppliers"));
	FilterList.Add(Catalogs.DefaultGLAccounts.GetDefaultGLAccount("CustomerAdvances"));
	FilterList.Add(Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AccountsReceivable"));
	FilterList.Add(Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AccountsPayable"));
	FilterList.Add(Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AdvanceHolders"));
	FilterList.Add(Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AdvanceHoldersPayable"));
	FilterList.Add(Catalogs.DefaultGLAccounts.GetDefaultGLAccount("PayrollPayable"));
	
	Return FilterList;
	
EndFunction

#EndRegion
