
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Object.Ref = Catalogs.IncomeAndExpenseItems.Undefined Then
		Cancel = True;
	EndIf;
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
	MethodOfDistributionChoiceList.LoadValues(Items.MethodOfDistribution.ChoiceList.UnloadValues());
	FormManagement();
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
EndProcedure

#EndRegion 

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

&AtClient
Procedure IncomeAndExpenseItemTypeOnChange(Item)
	
	FillIsIncomeExpense();
	FormManagement();
	
	If Object.IncomeAndExpenseType = PredefinedValue("Catalog.IncomeAndExpenseTypes.ManufacturingOverheads") Then
		Object.MethodOfDistribution = PredefinedValue("Enum.CostAllocationMethod.EmptyRef");
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillIsIncomeExpense()
	
	Result = Catalogs.IncomeAndExpenseTypes.FillIsIncomeExpense(Object.IncomeAndExpenseType);
	
	Object.IsIncome = Result.IsIncome;
	Object.IsExpense = Result.IsExpense;
	
EndProcedure

&AtServer
Procedure FormManagement()
	
	If (Object.IncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.OtherIncome
		Or Object.IncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.OtherExpenses
		Or Object.IncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.Revenue
		Or Object.IncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.CostOfSales
		Or Object.IncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.AdministrativeExpenses
		Or Object.IncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.OtherIncomeExpenses) Then
		
		Items.MethodOfDistribution.ChoiceList.Clear();
		Items.MethodOfDistribution.ChoiceList.Add(Enums.CostAllocationMethod.SalesVolume);
		Items.MethodOfDistribution.ChoiceList.Add(Enums.CostAllocationMethod.SalesRevenue);
		Items.MethodOfDistribution.ChoiceList.Add(Enums.CostAllocationMethod.CostOfGoodsSold);
		Items.MethodOfDistribution.ChoiceList.Add(Enums.CostAllocationMethod.GrossProfit);
		Items.MethodOfDistribution.ChoiceList.Add(Enums.CostAllocationMethod.DoNotDistribute);
		
	ElsIf Object.IncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.ManufacturingOverheads Then
		
		Items.MethodOfDistribution.ChoiceList.Clear();
		
	Else
		
		Items.MethodOfDistribution.ChoiceList.Clear();
		Items.MethodOfDistribution.ChoiceList.LoadValues(MethodOfDistributionChoiceList.UnloadValues());
		
	EndIf;
	
	Items.MethodOfDistribution.Visible = Object.IncomeAndExpenseType <> Catalogs.IncomeAndExpenseTypes.ManufacturingOverheads;
	
EndProcedure

#EndRegion