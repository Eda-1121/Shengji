# Card Styles

カード見た目のプリセット設定を置く場所です。

カード画像そのものは `assets/common/card_sets/` に置きます。ここには将来的に、カードセットごとの表示倍率、アクセシビリティ設定、説明文などのメタデータを置きます。

現在の実装では、利用可能なカードセットは `scripts/app/game_config.gd` の `CARD_STYLES` で管理しています。
