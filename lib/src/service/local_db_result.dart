
/// Because help to use [when] and [map] methods.
sealed class LocalDbResult<T, E>{
  const LocalDbResult();

  R when<R>({
    required R Function(T) ok,
    required R Function(E) err,
  }) {
    if (this is Ok<T, E>) {
      return ok((this as Ok<T, E>).data);
    }
    return err((this as Err<T, E>).error);
  }
}


class Ok<T, E> extends LocalDbResult<T, E>{
  final T data;
  const Ok(this.data);
}


class Err<T, E> extends LocalDbResult<T, E>{
  final E error;
  const Err(this.error);
}

extension ResultExtensions<T, E> on LocalDbResult<T, E> {

  LocalDbResult<R, E> map<R>(R Function(T value) transform) {
    if (this is Ok<T, E>) {
      return Ok(transform((this as Ok<T, E>).data));
    }

    return Err((this as Err<T, E>).error);
  }

  LocalDbResult<R, E> flatMap<R>(LocalDbResult<R, E> Function(T value) transform) {
    if (this is Ok<T, E>) {
      return transform((this as Ok<T, E>).data);
    }

    return Err((this as Err<T, E>).error);
  }

}