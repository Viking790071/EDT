#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		// The check of DataExchange.Import is not required, because operations with this register are 
		// performed during data exchange.
		
		If Common.IsSubordinateDIBNode() Then 
			MarkDataUpdatedInMasterNode();
		EndIf;
		
		Clear();
		Return;
	EndIf;
		
	If Count() > 0
		AND (Not ValueIsFilled(SessionParameters.UpdateHandlerParameters.DeferredProcessingQueue)
			Or Common.IsSubordinateDIBNode()
			Or (SessionParameters.UpdateHandlerParameters.ExecuteInMasterNodeOnly
			      AND Not StandardSubsystemsCached.DIBUsed())
			Or (Not SessionParameters.UpdateHandlerParameters.ExecuteInMasterNodeOnly
			      AND Not StandardSubsystemsCached.DIBUsed("WithFilter"))) Then
		
		Cancel = True;
		ExceptionText = NStr("ru = 'Запись в InformationRegister.DataProcessedInMasterDIBNode возможна только при отметке выполнения отложенного обработчика обновления информационной базы, который выполняется только в центральном узле.'; en = 'Data can only be saved to InformationRegister.DataProcessedInMasterDIBNode when the deferred infobase update handler running in the master node is marked completed.'; pl = 'Dane można zapisać tylko w InformationRegister.DataProcessedInMasterDIBNode, gdy program obsługi aktualizacji odroczonej bazy danych działający w węźle głównym jest oznaczony jako zakończony.';es_ES = 'El registro en InformationRegister.DataProcessedInMasterDIBNode es posible solo si hay marca de realización del procesador aplazado de la actualización de la infobase que se realiza solo en el nodo central.';es_CO = 'El registro en InformationRegister.DataProcessedInMasterDIBNode es posible solo si hay marca de realización del procesador aplazado de la actualización de la base de información que se realiza solo en el nodo central.';tr = 'InformationRegister.DataProcessedInMasterDIBNode kayıt yalnızca merkez ünitesinde yürütülen bekleyen bir veritabanı güncelleştirme işleyicisi çalıştırıldığında mümkündür.';it = 'I dati possono essere salvati nel InformationRegister.DataProcessedInMasterDIBNode solo quando il gestore di aggiornamenti differiti dell''infobase in esecuzione nel nodo master è contrassegnato come completato.';de = 'Die Aufzeichnung in den InformationRegister.DataProcessedInMasterDIBNode ist nur möglich, wenn der verzögerte Datenbank-Update-Handler markiert ist, der nur im zentralen Knoten ausgeführt wird.'");
		Raise ExceptionText;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Procedure MarkDataUpdatedInMasterNode()
	
	For Each StrTabl In ThisObject Do
		
		AdditionalParameters    = InfobaseUpdate.AdditionalProcessingMarkParameters();
		FullMetadataObjectName = Common.ObjectAttributeValue(StrTabl.MetadataObject, "FullName");
		
		If StrFind(FullMetadataObjectName, "AccumulationRegister") > 0
			Or StrFind(FullMetadataObjectName, "AccountingRegister") > 0
			Or StrFind(FullMetadataObjectName, "CalculationRegister") > 0 Then
			
			AdditionalParameters.IsRegisterRecords       = True;
			AdditionalParameters.FullRegisterName = FullMetadataObjectName;
			DataToMark                          = StrTabl.Data;
			
		ElsIf StrFind(FullMetadataObjectName, "InformationRegister") > 0 Then
			
			RegisterMetadata = Metadata.FindByFullName(FullMetadataObjectName);
			
			If RegisterMetadata.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.Independent Then
				
				RegisterManager = Common.ObjectManagerByFullName(FullMetadataObjectName);
				
				DataToMark = RegisterManager.CreateRecordSet();
				FilterValues   = StrTabl.IndependentRegisterFiltersValues.Get();
				
				For Each KeyValue In FilterValues Do
					DataToMark.Filter[KeyValue.Key].Set(KeyValue.Value);
				EndDo;
				
			Else
				
				AdditionalParameters.IsRegisterRecords = True;
				AdditionalParameters.FullRegisterName = FullMetadataObjectName;
				DataToMark = StrTabl.Data;
				
			EndIf;
			
		Else
			DataToMark = StrTabl.Data;
		EndIf;
		
		InfobaseUpdate.MarkProcessingCompletion(DataToMark, AdditionalParameters, StrTabl.PositionInQueue);	
		
		If DataExchange.Sender <> Undefined Then // not creation of the initial image
			SetToRegisterResponseToMasterNode = InformationRegisters.DataProcessedInMasterDIBNode.CreateRecordSet();
			SetToRegisterResponseToMasterNode.Filter.ExchangePlanNode.Set(StrTabl.ExchangePlanNode);
			SetToRegisterResponseToMasterNode.Filter.MetadataObject.Set(StrTabl.MetadataObject);
			SetToRegisterResponseToMasterNode.Filter.Data.Set(StrTabl.Data);
			SetToRegisterResponseToMasterNode.Filter.PositionInQueue.Set(StrTabl.PositionInQueue);
			SetToRegisterResponseToMasterNode.Filter.UniqueKey.Set(StrTabl.UniqueKey);
			
			ExchangePlans.RecordChanges(DataExchange.Sender, SetToRegisterResponseToMasterNode);
		EndIf;
		
	EndDo;

EndProcedure

#EndRegion

#EndIf