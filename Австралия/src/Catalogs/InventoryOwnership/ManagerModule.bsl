#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Function GetByParameters(Parameters, Cancel = False) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	
	Query.Text =
	"SELECT TOP 1
	|	InventoryOwnership.Ref AS Ref
	|FROM
	|	Catalog.InventoryOwnership AS InventoryOwnership
	|WHERE
	|	NOT InventoryOwnership.DeletionMark
	|	AND InventoryOwnership.OwnershipType = &OwnershipType
	|	AND (InventoryOwnership.Counterparty = &Counterparty
	|			OR &Counterparty = UNDEFINED)
	|	AND (InventoryOwnership.Contract = &Contract
	|			OR &Contract = UNDEFINED)";
	
	Query.SetParameter("OwnershipType", Parameters.OwnershipType);
	If Parameters.Property("Counterparty") Then
		Query.SetParameter("Counterparty", Parameters.Counterparty);
	Else
		Query.SetParameter("Counterparty", Undefined);
	EndIf;
	If Parameters.Property("Contract") Then
		Query.SetParameter("Contract", Parameters.Contract);
	Else
		Query.SetParameter("Contract", Undefined);
	EndIf;
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Sel = QueryResult.Select();
		Sel.Next();
		Return Sel.Ref;
		
	ElsIf Not Parameters.Property("DoNotCreate") Then
		
		NewItem = Catalogs.InventoryOwnership.CreateItem();
		NewItem.OwnershipType = Parameters.OwnershipType;
		If Parameters.Property("Counterparty") Then
			NewItem.Counterparty = Parameters.Counterparty;
		EndIf;
		If Parameters.Property("Contract") Then
			NewItem.Contract = Parameters.Contract;
		EndIf;
		
		Try
			
			NewItem.Write();
			Return NewItem.Ref;
			
		Except
			
			Cancel = True;
			ErrorInfo = ErrorInfo();
			ErrorMessage = BriefErrorDescription(ErrorInfo);
			CommonClientServer.MessageToUser(
				StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Couldn''t create new inventory ownership item. Try again later or contact your system administrator.
						|%1'; 
						|ru = 'Не удалось создать новый элемент владения запасами. Повторите попытку позже или обратитесь к системному администратору.
						|%1';
						|pl = 'Nie można utworzyć nowego elementu posiadania zapasami. Spróbuj ponownie później lub skontaktuj się ze swoim administratorem systemu.
						|%1';
						|es_ES = 'No se pudo crear un nuevo artículo de propiedad del inventario. Inténtelo de nuevo más tarde o póngase en contacto con el administrador del sistema.
						|%1';
						|es_CO = 'No se pudo crear un nuevo artículo de propiedad del inventario. Inténtelo de nuevo más tarde o póngase en contacto con el administrador del sistema.
						|%1';
						|tr = 'Yeni stok sahiplik öğesi oluşturulamadı. Daha sonra tekrar deneyin veya sistem yöneticinize başvurun.
						|%1';
						|it = 'Impossibile creare un nuovo elemento di proprietà di scorte. Riprovare più tardi o contattare l''amministratore di sistema.
						|%1';
						|de = 'Konnte keinen neuen Artikel der Bestandseigentümerschaft erstellen. Versuche es später erneut oder kontaktiere deinen Systemadministrator.
						|%1'"),
					ErrorMessage));
			
			WriteLogEvent(
				NStr("en = 'Inventory ownership.Create new item'; ru = 'Владение запасами.Создать новый элемент';pl = 'Posiadanie zapasami. Utwórz nowy element';es_ES = 'Propiedad del inventario. Crear un nuevo artículo';es_CO = 'Propiedad del inventario. Crear un nuevo artículo';tr = 'Stok sahipliği. Yeni öğe oluştur';it = 'Proprietà scorte. Creare nuovo elemento';de = 'Bestandseigentümerschaft. Neuen Artikel erstellen'", CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				Metadata.Catalogs.InventoryOwnership,
				,
				DetailErrorDescription(ErrorInfo));
			
				If TransactionActive() Then
					RollbackTransaction();
				EndIf;
			
		EndTry;
		
	EndIf;
	
	Return Undefined;
	
EndFunction

Function OwnInventory(Cancel = False) Export
	
	Parameters = New Structure;
	Parameters.Insert("OwnershipType", Enums.InventoryOwnershipTypes.OwnInventory);
	
	Return GetByParameters(Parameters, Cancel);
	
EndFunction

Procedure UpdateOnCounterpartyWrite(CounterpartyObject) Export
	
	ObjectData = UpdateRelatedData(CounterpartyObject);
	
	If Not ObjectData.UpdateNeeded Then
		Return;
	EndIf;
	
	ObjectData.Insert("Counterparty", ObjectData.Ref);
	ObjectData.Insert("Contract", Undefined);
	
	ExecuteUpdateRelatedData(ObjectData);
	
EndProcedure

Procedure UpdateOnContractWrite(ContractObject) Export
	
	ObjectData = UpdateRelatedData(ContractObject);
	
	If Not ObjectData.UpdateNeeded Then
		Return;
	EndIf;
	
	ObjectData.Insert("Counterparty", Undefined);
	ObjectData.Insert("Contract", ObjectData.Ref);
	
	ExecuteUpdateRelatedData(ObjectData);
	
EndProcedure

#EndRegion

#Region Private

Function UpdateRelatedData(Object)
	
	Data = New Structure("UpdateNeeded", False);
	
	If Object.IsNew() Or Object.AdditionalProperties.Property("DoNotUpdateInventoryOwnership") Then
		Return Data;
	EndIf;
	
	OldData = Common.ObjectAttributesValues(Object.Ref, "Description, DeletionMark");
	
	Data.Insert("Ref", Object.Ref);
	Data.Insert("OldDescription", TrimAll(OldData.Description));
	Data.Insert("NewDescription", TrimAll(Object.Description));
	Data.Insert("OldDeletionMark", OldData.DeletionMark);
	Data.Insert("NewDeletionMark", Object.DeletionMark);
	
	Data.UpdateNeeded = (Data.OldDescription <> Data.NewDescription)
		Or (Data.OldDeletionMark <> Data.NewDeletionMark);
	
	Return Data;
	
EndFunction

Procedure ExecuteUpdateRelatedData(ObjectData)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("Description", ObjectData.OldDescription);
	Query.SetParameter("Counterparty", ObjectData.Counterparty);
	Query.SetParameter("Contract", ObjectData.Contract);
	Query.Text =
	"SELECT
	|	InventoryOwnership.Ref AS Ref,
	|	CASE
	|		WHEN &Counterparty = UNDEFINED
	|			THEN CatalogCounterparties.DeletionMark
	|		ELSE CatalogCounterpartyContracts.DeletionMark
	|	END AS SecondRelatedDeletionMark
	|FROM
	|	Catalog.InventoryOwnership AS InventoryOwnership
	|		LEFT JOIN Catalog.Counterparties AS CatalogCounterparties
	|		ON InventoryOwnership.Counterparty = CatalogCounterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CatalogCounterpartyContracts
	|		ON InventoryOwnership.Contract = CatalogCounterpartyContracts.Ref
	|WHERE
	|	(InventoryOwnership.Counterparty = &Counterparty
	|			OR &Counterparty = UNDEFINED)
	|	AND (InventoryOwnership.Contract = &Contract
	|			OR &Contract = UNDEFINED)";
	
	Sel = Query.Execute().Select();
	
	While Sel.Next() Do
		
		OwnershipObject = Sel.Ref.GetObject();
		
		If ObjectData.OldDescription <> ObjectData.NewDescription Then
			OwnershipObject.Description = StrReplace(
				OwnershipObject.Description, ObjectData.OldDescription, ObjectData.NewDescription);
		EndIf;
		
		OwnershipObject.DeletionMark = ObjectData.NewDeletionMark Or Sel.SecondRelatedDeletionMark;
		
		OwnershipObject.Write();
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf