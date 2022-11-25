
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	IncomeAndExpenseItemsForFilling = IncomeAndExpenseItemsInDocuments.GetIncomeAndExpenseItemsForFillingByParameters(Parameters);
	FillForm(IncomeAndExpenseItemsForFilling);
	
	Height = 8;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, MessageText, StandardProcessing)
	
	If Exit And (Modified Or Select) Then
		Cancel = True;
		Return;
	EndIf;
	
	If Cancel Then
		Select = False;
	EndIf;

EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Select Then
		
		ResultStructure = New Structure;		
		
		VerticalGroup = Thisobject.ChildItems.GroupAttribute.ChildItems;
		
		For Each FormGroupItems In VerticalGroup Do
			
			If Not FormGroupItems.Visible Then
				Continue;
			EndIf;
			
			For Each Item In FormGroupItems.ChildItems Do
				ResultStructure.Insert(Item.Name, ThisObject[Item.Name]);
			EndDo;
			
		EndDo;
		
		IncomeAndExpenseItemsInDocumentsServerCall.GetIncomeAndExpenseItemsDescription(ResultStructure);
		ResultStructure.Insert("TableName", TableName);
		
		NotifyChoice(ResultStructure);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure RegisterBankFeeExpenseOnChange(Item)
	FillItem("BankFeeExpenseItem", RegisterBankFeeExpense);
EndProcedure

&AtClient
Procedure RegisterCommissionIncomeOnChange(Item)
	FillItem("CommissionIncomeItem", RegisterCommissionIncome);
EndProcedure

&AtClient
Procedure RegisterCommissionExpenseOnChange(Item)
	FillItem("CommissionExpenseItem", RegisterCommissionExpense);
EndProcedure

&AtClient
Procedure RegisterCOGSOnChange(Item)
	FillItem("COGSItem", RegisterCOGS);
EndProcedure

&AtClient
Procedure RegisterDepreciationChargeOnChange(Item)
	FillItem("DepreciationChargeItem", RegisterDepreciationCharge);
EndProcedure

&AtClient
Procedure RegisterDiscountAllowedExpenseOnChange(Item)
	FillItem("DiscountAllowedExpenseItem", RegisterDiscountAllowedExpense);
EndProcedure

&AtClient
Procedure RegisterDiscountReceivedIncomeOnChange(Item)
	FillItem("DiscountReceivedIncomeItem", RegisterDiscountReceivedIncome);
EndProcedure

&AtClient
Procedure RegisterIncomeOnChange(Item)
	FillItem("IncomeItem", RegisterIncome);
EndProcedure

&AtClient
Procedure RegisterExpenseOnChange(Item)
	FillItem("ExpenseItem", RegisterExpense);
EndProcedure

&AtClient
Procedure RegisterInterestAccruedIncomeOnChange(Item)
	FillItem("InterestAccruedIncomeItem", RegisterInterestAccruedIncome);
EndProcedure

&AtClient
Procedure RegisterInterestExpenseOnChange(Item)
	FillItem("InterestExpenseItem", RegisterInterestExpense);
EndProcedure

&AtClient
Procedure RegisterPurchaseReturnOnChange(Item)
	FillItem("PurchaseReturnItem", RegisterPurchaseReturn);
EndProcedure

&AtClient
Procedure RegisterRevaluationOnChange(Item)
	FillItem("RevaluationItem", RegisterRevaluation);
EndProcedure

&AtClient
Procedure RegisterRevenueOnChange(Item)
	FillItem("RevenueItem", RegisterRevenue);
EndProcedure

&AtClient
Procedure RegisterSalesReturnOnChange(Item)
	FillItem("SalesReturnItem", RegisterSalesReturn);
EndProcedure

&AtClient
Procedure RegisterCostOfSalesOnChange(Item)
	FillItem("CostOfSalesItem", RegisterCostOfSales);
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Cancel(Command)
	
	Select = False;
	Modified = False;
	Close();
	
EndProcedure

&AtClient
Procedure OK(Command)
	
	Select = True;
	Close();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillForm(Parameters)
	
	Var ObjectParameters;
	
	Parameters.Property("TabName", TableName);
	Parameters.Property("ObjectParameters", ObjectParameters);
	
	IsRegistrationOptional = ?(
		ObjectParameters = Undefined, 
		False, 
		IncomeAndExpenseItemsInDocuments.RegistrationIsOptional(ObjectParameters.Ref));
		
		
	If ObjectParameters <> Undefined And TypeOf(ObjectParameters.Ref) = Type("DocumentRef.Payroll")
			And TableName = "LoanRepayment" Then
		IsRegistrationOptional = False;
	EndIf;
		
	VerticalGroup = Items.GroupAttribute.ChildItems;
	
	For Each FormGroupItems In VerticalGroup Do
		
		For Each Item In FormGroupItems.ChildItems Do
			IsFormGroupVisible = Parameters.Property(Item.Name, ThisForm[Item.Name]);
		EndDo;
		
		FormGroupItems.Visible = IsFormGroupVisible;
		
		If IsFormGroupVisible Then
			
			RegisterItemName = "Register" + Mid(FormGroupItems.Name, 6, StrLen(FormGroupItems.Name) - 9);
			
			If IsRegistrationOptional Then
				Items[RegisterItemName].Visible = True;
				Item.Enabled = ThisObject[RegisterItemName];
			Else
				Items[RegisterItemName].Visible = False;
				Item.Enabled = True;
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure FillItem(Item, Value)
	
	If Not Value Then
		ThisObject[Item] = Undefined;
	EndIf;
	
	Items[Item].Enabled = Value;
	
EndProcedure

#EndRegion