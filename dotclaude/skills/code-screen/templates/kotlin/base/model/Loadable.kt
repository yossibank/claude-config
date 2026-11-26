package __modelPackage__

sealed interface Loadable<out Value> {
    data object Loading : Loadable<Nothing>

    data class Loaded<Value>(
        override val value: Value,
    ) : Loadable<Value>

    data object Failed : Loadable<Nothing>

    val value: Value?
        get() = null

    val isLoaded: Boolean
        get() = this is Loaded

    val isFailed: Boolean
        get() = this == Failed

    val isSettled: Boolean
        get() = this != Loading

    val retrying: Loadable<Value>
        get() = if (isFailed) Loading else this
}
