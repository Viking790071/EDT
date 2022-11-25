#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	Order = MaxPriorityOrder() + 1;
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	Order = MaxPriorityOrder() + 1;
	
EndProcedure

#EndRegion

#Region Private

Function MaxPriorityOrder()
	
	Result = 0;
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	ProductionOrdersPriorities.Order AS Order
	|FROM
	|	Catalog.ProductionOrdersPriorities AS ProductionOrdersPriorities
	|WHERE
	|	NOT ProductionOrdersPriorities.DeletionMark
	|
	|ORDER BY
	|	Order DESC";
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	If SelectionDetailRecords.Next() Then
		Result = SelectionDetailRecords.Order;
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#EndIf
