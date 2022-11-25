#Region ProcedureFormEventHandlers

&AtServer
// Procedure-handler of the OnCreateAtServer event.
// Performs initial attributes forms filling.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Filter") AND Parameters.Filter.Property("Products") Then

		Products = Parameters.Filter.Products;

		If Products.ProductsType <> Enums.ProductsTypes.Work Then
			
			AutoTitle = False;
			Title = NStr("en = 'Standard hours are stored only for works'; ru = 'Нормы времени хранятся только для работ';pl = 'Normy czasowe są przechowywane tylko dla prac';es_ES = 'Horas estándar se han almacenado solo para trabajos';es_CO = 'Horas estándar se han almacenado solo para trabajos';tr = 'Standart süre sadece işler için saklanır';it = 'Ore standard vengono memorizzate solo per i lavori';de = 'Richtwertsätze werden nur für Arbeiten gespeichert'");

			Items.List.ReadOnly = True;
			
		EndIf;

	EndIf;
		
EndProcedure

#EndRegion
