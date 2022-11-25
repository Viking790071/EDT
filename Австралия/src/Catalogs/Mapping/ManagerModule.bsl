#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	NativeLanguagesSupportServer.ChoiceDataGetProcessing(
		ChoiceData,
		Parameters,
		StandardProcessing,
		Metadata.Catalogs.Mapping);
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

#EndRegion

#Region Internal

Procedure ChangeObjectByParameters(Parameters) Export
	
	If Not ValueIsFilled(Parameters.Ref) Then
		
		Query = New Query(
		"SELECT
		|	Mapping.Ref AS Ref
		|FROM
		|	Catalog.Mapping AS Mapping
		|WHERE
		|	Mapping.SourceAccount = &SourceAccount
		|	AND Mapping.CorrSourceAccount = &CorrSourceAccount
		|	AND Mapping.ReceivingAccount = &ReceivingAccount
		|	AND Mapping.MappingID = &MappingID
		|	AND Mapping.Owner = &Owner
		|");
		
		Query.SetParameter("SourceAccount"    , Parameters.SourceAccount);
		Query.SetParameter("CorrSourceAccount", Parameters.CorrSourceAccount);
		Query.SetParameter("ReceivingAccount" , Parameters.ReceivingAccount);
		Query.SetParameter("MappingID"        , Parameters.MappingID);
		Query.SetParameter("Owner"            , Parameters.Owner);
		
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			CatalogObject = Selection.Ref.GetObject();
		Else
			
			CatalogObject = Catalogs.Mapping.CreateItem();
			FillPropertyValues(CatalogObject, Parameters);
			CatalogObject.Description = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Translation from account %1 to account %2'; ru = 'Трансляция из учетной записи %1 в учетную запись %2';pl = 'Tłumaczenie z konta %1 na konto %2';es_ES = 'Transferencia de cuenta %1 a cuenta %2';es_CO = 'Transferencia de cuenta %1 a cuenta %2';tr = '%1 hesabından %2 hesabına aktarım';it = 'Traslazione dal conto %1 al conto %2';de = 'Übersetzung von Konto %1 zu Konto %2'"),
				Parameters.SourceAccount,
				Parameters.ReceivingAccount);
			
		EndIf;
		
	Else
		CatalogObject = Parameters.Reg.GetObject();
	EndIf;
	
	BeginTransaction();
	Try
		CatalogObject.Write();
		Parameters.Insert("Ref", CatalogObject.Ref);
		CommitTransaction();
	Except
		RollbackTransaction();
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Can''t write item %1 by reason: %2'; ru = 'Невозможно выполнить запись элемента %1. Причина: %2';pl = 'Nie można zapisać pozycji %1 z powodu: %2';es_ES = 'No se puede escribir el artículo %1 por causa de: %2';es_CO = 'No se puede escribir el artículo %1 por causa de: %2';tr = '%1 kalemi yazamama sebebi: %2';it = 'Impossibile registrare elemento %1 a causa di: %2';de = 'Artikel %1 kann aus folgendem Grund nicht geschrieben werden: %2'"),
			CatalogObject.Name,
			ErrorDescription());
			
		CommonClientServer.MessageToUser(ErrorMessage);
		Raise;
	EndTry;
	
EndProcedure

Function RollbackMapping(TransformationTemplate, SourceAccount, CorrSourceAccount, ReceivingAccount, MappingID) Export
	
	Query = New Query(
	"SELECT
	|	Mapping.Ref AS Ref
	|FROM
	|	Catalog.Mapping AS Mapping
	|WHERE
	|	Mapping.Owner = &Owner
	|	AND Mapping.SourceAccount = &SourceAccount
	|	AND Mapping.ReceivingAccount = &ReceivingAccount
	|	AND Mapping.CorrSourceAccount = &CorrSourceAccount
	|	AND Mapping.MappingID = &MappingID
	|");
	
	Query.SetParameter("SourceAccount"    , SourceAccount);
	Query.SetParameter("ReceivingAccount" , ReceivingAccount);
	Query.SetParameter("CorrSourceAccount", CorrSourceAccount);
	Query.SetParameter("Owner"            , TransformationTemplate);
	Query.SetParameter("MappingID"        , MappingID);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Result = Selection.Ref;
	Else
		Result = Undefined;
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#EndIf
