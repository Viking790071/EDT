
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Period") Then
		
		Parameters.Property("Period"	, Record.Period);
		Parameters.Property("Company"	, Record.Company);
		
	EndIf;
	
	Parameters.Property("IsNew", IsNew);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	CheckDuplicates(Cancel);
	
EndProcedure

&AtClient
Procedure InactiveOnChange(Item)
	
	If Record.Inactive And Not ValueIsFilled(Record.EndDate) Then
		Record.EndDate = EndOfDay(Record.Period - 86400);
	ElsIf Not Record.Inactive And ValueIsFilled(Record.EndDate) Then
		Record.EndDate = Undefined;
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	Cancel = True;
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure CheckDuplicates(Cancel)

	If Not IsNew Then
		Return;
	EndIf;
		
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	CompaniesTypesOfAccounting.EntriesPostingOption AS EntriesPostingOption
	|FROM
	|	InformationRegister.CompaniesTypesOfAccounting.SliceLast(
	|			&Period,
	|			Company = &Company
	|				AND TypeOfAccounting = &TypeOfAccounting) AS CompaniesTypesOfAccounting
	|WHERE
	|	NOT CompaniesTypesOfAccounting.Inactive";
	
	Query.SetParameter("Company", Record.Company);
	Query.SetParameter("Period", Record.Period);
	Query.SetParameter("TypeOfAccounting", Record.TypeOfAccounting);
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		ErrMessage = NStr("en = 'Cannot save this type of accounting. 
			|Type of accounting with similar type and chart of accounts is already added to the list.'; 
			|ru = 'Не удалось сохранить тип бухгалтерского учета. 
			|Тип бухгалтерского учета с аналогичным типом и планом счетов уже есть в списке.';
			|pl = 'Nie można zapisać tego typu rachunkowości. 
			|Typ rachunkowo]ci z tym samym typem i planem kont jest już dodany do listy.';
			|es_ES = 'No se puede guardar este tipo de contabilidad.
			| El tipo de contabilidad con un tipo y un diagrama de cuentas similares ya se ha añadido a la lista.';
			|es_CO = 'No se puede guardar este tipo de contabilidad.
			| El tipo de contabilidad con un tipo y un diagrama de cuentas similares ya se ha añadido a la lista.';
			|tr = 'Bu muhasebe türü kaydedilemiyor.
			|Aynı türe ve hesap planına sahip muhasebe türü zaten listeye eklendi.';
			|it = 'Impossibile salvare questo tipo di contabilità.
			|Un tipo di contabilità con tipo simile e piano dei conti è già aggiunto all''elenco.';
			|de = 'Fehler beim Speicher dieses Typs der Buchhaltung. 
			|Typ der Buchhaltung mit ähnlichem Typ und Kontenplan ist bereits zur Liste hinzugefügt.'");
		DriveServer.ShowMessageAboutError(ThisObject, ErrMessage, , , , Cancel);
		
	EndIf;

EndProcedure

#EndRegion