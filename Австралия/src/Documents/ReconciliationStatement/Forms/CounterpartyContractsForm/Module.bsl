

#Region ProcedureFormEventHandlers

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	StandardProcessing = False;
	
	Counterparty	= Parameters.Counterparty;
	Company			= Parameters.Company;
	
	CounterpartyContracts.Load(Parameters.CounterpartyContracts.Unload());
	
	CheckContractsFilling = False;
	
EndProcedure

&AtClient
// Procedure - event handler BeforeClose form.
//
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Exit Then
		Return;
	EndIf;
	
	If CheckContractsFilling Then
	
		For Each Contract In CounterpartyContracts Do
			
			If Not ValueIsFilled(Contract.Contract) Then
				
				MessageText = NStr("en = 'There are rows with a blank counterparty contract in the table'; ru = 'В таблице присутствуют строки с незаполненным договором контрагента';pl = 'Tabela zawiera wiersze z niewypełnioną umową kontrahenta';es_ES = 'Hay filas con un contrato de la contraparte en blanco en la tabla';es_CO = 'Hay filas con un contrato de la contraparte en blanco en la tabla';tr = 'Tabloda boş cari hesap sözleşmesi olan satırlar var';it = 'Nella tabella ci sono linee con un contratto inevaso della controparte';de = 'In der Tabelle gibt es Zeilen mit einem leeren Geschäftspartnervertrag'");
				CommonClientServer.MessageToUser(MessageText, , , , Cancel);
				Break;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region CommandHandlers

&AtClient
// Procedure command handler OK
//
Procedure OK(Command)
	
	CheckContractsFilling = True;
	Modified = False;
	Close(New Structure("CounterpartyContracts", CounterpartyContracts));
	
EndProcedure

&AtClient
// Procedure command handler Cancel
//
Procedure Cancel(Command)
	
	CheckContractsFilling = False;
	Modified = False;
	Close();
	
EndProcedure

&AtClient
// Procedure command handler SelectCheckboxes
//
Procedure CheckAll(Command)
	
	For Each ListRow In CounterpartyContracts Do
		
		ListRow.Select = True;
		
	EndDo;
	
EndProcedure

&AtClient
// Procedure command handler SelectCheckboxes
//
Procedure UncheckAll(Command)
	
	For Each ListRow In CounterpartyContracts Do
		
		ListRow.Select = False;
		
	EndDo;
	
EndProcedure
// 

#EndRegion
