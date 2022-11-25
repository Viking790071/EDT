#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
#Region EventHandlers

Procedure BeforeWrite(Cancel)
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not CheckUniqueID() Then
		Cancel = True;
		MessageText = NStr("en = 'Already exists a mandate with the same ID'; ru = 'Мандат с таким идентификатором уже существует';pl = 'Już istnieje zlecenie o tym samym ID';es_ES = 'Ya existe un mandato con el mismo identificador';es_CO = 'Ya existe un mandato con el mismo identificador';tr = 'Aynı kimliğe sahip talimat zaten mevcut';it = 'Esiste già un mandato con lo stesso ID';de = 'Lastschriftmandat mit derselben ID bereits existiert'");
		CommonClientServer.MessageToUser(MessageText,,,,False);
	EndIf;
	
	Description = Catalogs.DirectDebitMandates.ComposeDesctiption(ThisObject);
	
EndProcedure

#EndRegion

#Region Private

Function CheckUniqueID()
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	DirectDebitMandates.Ref AS Ref
	|FROM
	|	Catalog.DirectDebitMandates AS DirectDebitMandates
	|WHERE
	|	DirectDebitMandates.Ref <> &Ref
	|	AND DirectDebitMandates.MandateID = &MandateID";
	Query.SetParameter("Ref",Ref);
	Query.SetParameter("MandateID",MandateID);
	
	Return(Query.Execute().IsEmpty());	
EndFunction

#EndRegion

#EndIf