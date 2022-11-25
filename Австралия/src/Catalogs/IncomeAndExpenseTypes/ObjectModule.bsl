#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not Ref.IsEmpty() Then
		
		If DeletionMark Then
			Raise Nstr("en = 'Cannot delete income and expense type.'; ru = 'Не удалось удалить тип доходов и расходов.';pl = 'Nie można usunąć typu dochodów i rozchodów.';es_ES = 'No se ha podido borrar el tipo de ingresos y gastos.';es_CO = 'No se ha podido borrar el tipo de ingresos y gastos.';tr = 'Gelir ve gider türü silinemedi.';it = 'Impossibile eliminare il tipo di entrata e uscita.';de = 'Fehler beim Löschen des Typs von Einnahme und Ausgaben.'");
		EndIf;
		
		RefCategory = Common.ObjectAttributeValue(Ref, "IncomeAndExpenseCategory");
		If IncomeAndExpenseCategory <> RefCategory Then
			AdditionalProperties.Insert("CategoryIsChange");
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If AdditionalProperties.Property("CategoryIsChange") Then
		FillIncomeAndExpenseItemsAttributes();
	EndIf;
	
EndProcedure

#EndRegion

#Region Internal

Procedure OnReadPresentationsAtServer(Object) Export
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
EndProcedure

#EndRegion

#Region Private

Procedure FillIncomeAndExpenseItemsAttributes()
	
	Income = Enums.IncomeAndExpenseCategories.Income;
	Expense = Enums.IncomeAndExpenseCategories.Expense;
	IncomeExpense = Enums.IncomeAndExpenseCategories.IncomeExpense;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	IncomeAndExpenseItems.Ref AS Ref
	|FROM
	|	Catalog.IncomeAndExpenseItems AS IncomeAndExpenseItems
	|WHERE
	|	IncomeAndExpenseItems.IncomeAndExpenseType = &IncomeAndExpenseType";
	
	Query.SetParameter("IncomeAndExpenseType", Ref);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		IncomeAndExpenseItemObject = Selection.Ref.GetObject();
		If IncomeAndExpenseItemObject = Undefined Or Selection.Ref.IsEmpty() Then
			Continue;
		EndIf;
		
		IncomeAndExpenseItemObject.IsIncome = (IncomeAndExpenseCategory <> Expense);
		IncomeAndExpenseItemObject.IsExpense = (IncomeAndExpenseCategory <> Income);
		
		IncomeAndExpenseItemObject.Write();
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf