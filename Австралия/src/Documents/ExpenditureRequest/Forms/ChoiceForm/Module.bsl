
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("ParameterCalculatedOperation")
		And (Parameters.ParameterCalculatedOperation = Enums.OperationTypesPaymentExpense.Vendor
		Or Parameters.ParameterCalculatedOperation = Enums.OperationTypesCashVoucher.Vendor) Then
		
		CommonClientServer.SetDynamicListFilterItem(List, "CalculatedOperation", "Supplier");
		
	ElsIf Parameters.Property("ParameterCalculatedOperation")
		And (Parameters.ParameterCalculatedOperation = Enums.OperationTypesPaymentExpense.Salary
		Or Parameters.ParameterCalculatedOperation = Enums.OperationTypesCashVoucher.Salary) Then
		
		CommonClientServer.SetDynamicListFilterItem(List, "CalculatedOperation", "Payroll");
		
	EndIf;
	
EndProcedure

#EndRegion

