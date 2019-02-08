{-# LANGUAGE ConstraintKinds       #-}
{-# LANGUAGE DataKinds             #-}
{-# LANGUAGE DeriveGeneric         #-}
{-# LANGUAGE ExtendedDefaultRules  #-}
{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE KindSignatures        #-}
{-# LANGUAGE LambdaCase            #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE QuasiQuotes           #-}
{-# LANGUAGE RecursiveDo           #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE StandaloneDeriving    #-}
{-# LANGUAGE TemplateHaskell       #-}
{-# LANGUAGE TupleSections         #-}

-- | Confirmation dialog for deploying modules and calling functions on the
-- backend.
-- Copyright   :  (C) 2018 Kadena
-- License     :  BSD-style (see the file LICENSE)
module Frontend.UI.Dialogs.DeployConfirmation
  ( uiDeployConfirmation
  ) where

------------------------------------------------------------------------------
import           Control.Lens
import           Data.Bifunctor
import qualified Data.Map                as Map
import           Data.Void               (Void)
import           Reflex
import           Reflex.Dom
------------------------------------------------------------------------------
import           Frontend.Backend
import           Frontend.Ide
import           Frontend.ModuleExplorer (HasModuleExplorerCfg (..))
import           Frontend.UI.Modal
import           Frontend.UI.Widgets
import           Frontend.UI.DeploymentSettings
------------------------------------------------------------------------------


-- | Confirmation dialog for deployments.
--
--   User can make sure to deploy to the right backend, has the right keysets,
--   the right keys, ...
uiDeployConfirmation
  :: forall t m a. MonadWidget t m
  => Ide a t
  -> m (IdeCfg Void t, Event t ())
uiDeployConfirmation ideL = do
  onClose <- modalHeader $ text "Deployment Settings"
  modalMain $ do
    (settingsCfg, transInfo) <- modalBody $ do
      d <- divClass "segment" $ do
        elClass "h2" "heading heading_type_h2" $ text "Choose a Server "

        let backends = ffor (_backend_backends $ _ide_backend ideL) $
              fmap (\(k, _) -> (k, textBackendName k)) . maybe [] Map.toList
            mkOptions bs = Map.fromList $ (Nothing, "Deployment Target") : map (first Just) bs

            cfg = def & dropdownConfig_attributes .~ pure ("class" =: "select select_type_primary")
        dropdown Nothing (mkOptions <$> backends) cfg

      (settingsCfg, signingKeys, _) <- elClass "div" "segment" $
        uiDeploymentSettings ideL Nothing

      pure
        ( settingsCfg
        , do
            s <- signingKeys
            mb <- value d
            pure $ TransactionInfo s <$> mb
        )

    modalFooter $ do
      onCancel <- cancelButton def "Cancel"
      text " "
      let isDisabled = maybe True (const False) <$> transInfo
      onConfirm <- confirmButton (def & uiButtonCfg_disabled .~ isDisabled) "Deploy"

      -- TODO: Use `backendCfg_deployCode` instead.
      let cfg = mempty & moduleExplorerCfg_deployEditor .~
            fmapMaybe id (tagPromptlyDyn transInfo onConfirm)
      pure (cfg <> settingsCfg, leftmost [onClose, onCancel, onConfirm])
