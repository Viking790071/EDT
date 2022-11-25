
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
					|ru = 'Выберите элемент, а не группу.
					|Используйте комбинацию ""Ctrl"" и стрелку вверх или стрелку вниз, или кнопки + и - на цифровой панели для того, чтобы сворачивать и разворачивать группы.';
					|pl = 'Wybierz element, a nie grupę.
					|Aby rozwinąć grupę, użyj klawiszy ""Ctrl"" i strzałek ""w górę"" i ""w dół"" lub klawiszy ""+"" i ""-"" na klawiaturze numerycznej.';
					|es_ES = 'Seleccione un elemento en vez de grupo.
					|Para maximizar el grupo use ""Ctrl"" y las teclas flecha arriba o flecha abajo o las teclas ""+"" y ""-"" en el teclado numérico.';
					|es_CO = 'Seleccione un elemento en vez de grupo.
					|Para maximizar el grupo use ""Ctrl"" y las teclas flecha arriba o flecha abajo o las teclas ""+"" y ""-"" en el teclado numérico.';
					|tr = 'Bir kalem seçin, grup değil. 
					| Bir grubu genişletmek için ""Ctrl"" ve Yukarı Ok ve Aşağı Ok tuşlarını veya sayı tuş takımındaki ""+"" ve ""-"" tuşlarını kullanın.';
					|it = 'Selezionare un elemento, non un gruppo.
					|Per espandere un gruppo utilizzare ""Ctrl"" e la freccia in alto e basso o i tasti ""+"" o ""-"" nel tastierino numerico.';
					|de = 'Wählen Sie ein Element aus, nicht eine Gruppe.
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
	
	Item.Appearance.SetParameterValue("Text", NStr("en = 'Direct Distribution'; ru = 'Непосредственное распределение';pl = 'Dystrybucja bezpośrednia';es_ES = 'Distribución directa';es_CO = 'Distribución directa';tr = 'Direkt dağıtım';it = 'Distribuzione diretta';de = 'Direkte Verteilung'"));
	
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
				InvoiceHeader = NStr("en = 'Expenses allocated to the financial result (Indirect)'; ru = 'Расходы, распределяемые на финансовый результат (Косвенные)';pl = 'Koszty przydzielane do wyniku finansowego (pośrednie)';es_ES = 'Gastos asignados al resultado financiero (Indirectos)';es_CO = 'Gastos asignados al resultado financiero (Indirectos)';tr = 'Finansal sonuca dağıtılan giderler (Dolaylı)';it = 'Spese assegnate al risultato finanziario (indirette)';de = 'Dem Finanzergebnis zugewiesene Ausgaben (Indirekt)'");
			ElsIf CurAccountType = Enums.GLAccountsTypes.OtherExpenses Then
				InvoiceHeader = NStr("en = 'Other expenses allocated to the financial result'; ru = 'Прочие расходы, распределяемые на финансовый результат';pl = 'Pozostałe koszty przydzielone do wyniku finansowego';es_ES = 'Otros gastos asignados al resultado financiero';es_CO = 'Otros gastos asignados al resultado financiero';tr = 'Finansal sonuca dağıtılan diğer giderler';it = 'Altre spese assegnate al risultato finanziario';de = 'Sonstige dem Finanzergebnis zugewiesene Ausgaben'");
			ElsIf  CurAccountType = Enums.GLAccountsTypes.Revenue Then
				InvoiceHeader = NStr("en = 'Income allocated to the financial result'; ru = 'Доходы, распределяемые на финансовый результат';pl = 'Dochód przydzielony do wyniku finansowego';es_ES = 'Ingreso asignado al resultado financiero';es_CO = 'Ingreso asignado al resultado financiero';tr = 'Finansal sonuca dağıtılan gelir';it = 'Entrate assegnate al risultato finanziario';de = 'Dem Finanzergebnis zugewiesene Einnahmen'");
			ElsIf CurAccountType = Enums.GLAccountsTypes.OtherIncome Then
				InvoiceHeader = NStr("en = 'Other income allocated to the financial result'; ru = 'Прочие доходы, распределяемые на финансовый результат';pl = 'Pozostałe dochody przydzielone do wyniku finansowego';es_ES = 'Otro ingreso asignado al resultado financiero';es_CO = 'Otro ingreso asignado al resultado financiero';tr = 'Finansal sonuca dağıtılan diğer gelir';it = 'Altri proventi assegnati al risultato finanziario';de = 'Sonstige dem Finanzergebnis zugewiesene Einnahmen'");
			ElsIf CurAccountType = Enums.GLAccountsTypes.AccountsReceivable Then
				InvoiceHeader = NStr("en = 'Other debtors (debt to us)'; ru = 'Прочие дебиторы (задолженность перед нами)';pl = 'Inni dłużnicy (dług wobec nas)';es_ES = 'Otros deudores (deuda para nosotros)';es_CO = 'Otros deudores (deuda para nosotros)';tr = 'Diğer borçlular (bize olan borç)';it = 'Altri debitori (debito verso di noi)';de = 'Andere Debitoren (Schulden an uns)'");
			ElsIf CurAccountType = Enums.GLAccountsTypes.AccountsPayable Then
				InvoiceHeader = NStr("en = 'Other creditors (our debt)'; ru = 'Прочие кредиторы (наша задолженность)';pl = 'Inni wierzyciele (nasz dług)';es_ES = 'Otros acreedores (nuestra deuda)';es_CO = 'Otros acreedores (nuestra deuda)';tr = 'Diğer alacaklılar (bizim borcumuz)';it = 'Altri creditori (nostro debito)';de = 'Andere Kreditoren (unsere Schulden)'");
			ElsIf CurAccountType = Enums.GLAccountsTypes.CashAndCashEquivalents Then
				InvoiceHeader = NStr("en = 'Funds transfer'; ru = 'Перемещения денег';pl = 'Transfer funduszy';es_ES = 'Transferencia de fondos';es_CO = 'Transferencia de fondos';tr = 'Fon transferi';it = 'Trasferimento fondi';de = 'Geldüberweisung'");
			ElsIf CurAccountType = Enums.GLAccountsTypes.LongtermLiabilities Then
				InvoiceHeader = NStr("en = 'Long-term liabilities'; ru = 'Долгосрочные обязательства';pl = 'Długoterminowe zobowiązania';es_ES = 'Obligaciones a largo plazo';es_CO = 'Obligaciones a largo plazo';tr = 'Uzun vadeli yükümlülükler';it = 'Passività a lungo termine';de = 'Langfristige Verbindlichkeiten'");
			ElsIf CurAccountType = Enums.GLAccountsTypes.Capital Then
				InvoiceHeader = NStr("en = 'Capital'; ru = 'Капитал';pl = 'Kapitał';es_ES = 'Capital';es_CO = 'Capital';tr = 'Sermaye';it = 'Capitale sociale';de = 'Kapital'");
			ElsIf CurAccountType = Enums.GLAccountsTypes.LoansBorrowed Then
				InvoiceHeader = NStr("en = 'Credits and Loans'; ru = 'Кредиты и займы';pl = 'Kredyty i pożyczki';es_ES = 'Créditos y Préstamos';es_CO = 'Créditos y Préstamos';tr = 'Krediler ve Borçlar';it = 'Crediti e prestiti';de = 'Kredite und Darlehen'");
			ElsIf CurAccountType = Enums.GLAccountsTypes.WorkInProgress Then
				InvoiceHeader = NStr("en = 'Expenses related to product release (Direct)'; ru = 'Затраты, относящиеся к выпуску продукции (Прямые)';pl = 'Koszty związane z wytworzeniem produktu (Bezpośrednie)';es_ES = 'Gastos relacionados con el lanzamiento del producto (Directos)';es_CO = 'Gastos relacionados con el lanzamiento del producto (Directos)';tr = 'Ürün imalatı ile ilgili giderler (Direkt)';it = 'Spese relative al rilascio prodotto (Dirette)';de = 'Ausgaben im Zusammenhang mit der Produktfreigabe (Direkt)'");
			ElsIf CurAccountType = Enums.GLAccountsTypes.IndirectExpenses Then
				InvoiceHeader = NStr("en = 'Costs allocated to product release cost (Indirect)'; ru = 'Затраты, распределяемые на себестоимость выпуска продукции (Косвенные)';pl = 'Koszty przypisane do kosztów wytwarzania produktu (Pośrednie)';es_ES = 'Costes asignados al coste del lanzamiento del producto (Indirectos)';es_CO = 'Costes asignados al coste del lanzamiento del producto (Indirectos)';tr = 'Ürün imalat maliyetine dağıtılan giderler (Dolaylı)';it = 'Costi imputati al costo di rilascio del prodotto (indiretto)';de = 'Den Produktfreigabekosten zugeordnete Kosten (Indirekt)'");
			ElsIf CurAccountType = Enums.GLAccountsTypes.OtherCurrentAssets Then
				InvoiceHeader = NStr("en = 'Other Current Assets'; ru = 'Прочие оборотные активы';pl = 'Inne aktywa obrotowe';es_ES = 'Otros activos actuales';es_CO = 'Otros activos actuales';tr = 'Diğer Dönen Varlıklar';it = 'Altre attività correnti';de = 'Sonstige kurzfristige Vermögenswerte'");
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
